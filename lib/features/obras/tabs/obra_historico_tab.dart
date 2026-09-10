import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../models/obra.dart';
import '../../../models/obra_historico.dart';
import '../../../providers/obra_providers.dart';
import '../../../providers/supabase_providers.dart';

const _tipoConfig = <String, (String, IconData, Color)>{
  'producao': ('Produção', Icons.inventory_2_outlined, AppColors.primary),
  'despacho': ('Despacho', Icons.local_shipping_outlined, AppColors.info),
  'montagem': ('Montagem', Icons.construction_outlined, AppColors.success),
  'etapa': ('Etapa', Icons.timeline, AppColors.warning),
  'observacao': ('Observação', Icons.chat_bubble_outline, AppColors.mutedForeground),
  'foto': ('Foto', Icons.image_outlined, Color(0xFF8B5CF6)),
  'anexo': ('Anexo', Icons.attach_file, Color(0xFFF97316)),
  'manual': ('Manual', Icons.description_outlined, AppColors.mutedForeground),
  'planejamento': ('Planejamento', Icons.event_note_outlined, Color(0xFFD97706)),
  'auditoria': ('Auditoria', Icons.verified_outlined, AppColors.mutedForeground),
};

/// Aba "Histórico" da obra.
class ObraHistoricoTab extends ConsumerStatefulWidget {
  const ObraHistoricoTab({
    super.key,
    required this.obraId,
    required this.obra,
  });

  final String obraId;
  final Obra obra;

  @override
  ConsumerState<ObraHistoricoTab> createState() => _ObraHistoricoTabState();
}

class _ObraHistoricoTabState extends ConsumerState<ObraHistoricoTab> {
  final _busca = TextEditingController();
  String _tipoFiltro = 'todos';

  @override
  void dispose() {
    _busca.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final histAsync = ref.watch(obraHistoricoProvider(widget.obraId));

    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _adicionarManual,
        icon: const Icon(Icons.add_comment_outlined),
        label: const Text('Registro'),
      ),
      body: histAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erro: $e')),
        data: (itens) {
          final tipos = itens.map((e) => e.tipo).toSet().toList()..sort();
          final termo = _busca.text.trim().toLowerCase();
          final filtrados = itens.where((i) {
            if (_tipoFiltro != 'todos' && i.tipo != _tipoFiltro) return false;
            if (termo.isEmpty) return true;
            final alvo =
                '${i.descricao} ${i.detalhes ?? ''} ${i.responsavel ?? ''}'
                    .toLowerCase();
            return alvo.contains(termo);
          }).toList();

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Column(
                  children: [
                    TextField(
                      controller: _busca,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        hintText: 'Buscar no histórico',
                        prefixIcon: Icon(Icons.search),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: _tipoFiltro,
                      decoration: const InputDecoration(
                          labelText: 'Tipo', isDense: true),
                      items: [
                        const DropdownMenuItem(
                            value: 'todos', child: Text('Todos')),
                        ...tipos.map((t) => DropdownMenuItem(
                              value: t,
                              child: Text(
                                  _tipoConfig[t]?.$1 ?? t),
                            )),
                      ],
                      onChanged: (v) =>
                          setState(() => _tipoFiltro = v ?? 'todos'),
                    ),
                    const SizedBox(height: 6),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '${filtrados.length} registro(s)',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.mutedForeground,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: filtrados.isEmpty
                    ? const EmptyState(
                        icon: Icons.history,
                        title: 'Nenhum registro',
                        message: 'O histórico é alimentado automaticamente '
                            'pelas alterações das peças.',
                      )
                    : RefreshIndicator(
                        onRefresh: () async => ref
                            .invalidate(obraHistoricoProvider(widget.obraId)),
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                          itemCount: filtrados.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 8),
                          itemBuilder: (_, index) => _HistoricoTile(
                            item: filtrados[index],
                            onEditar: _editarManual,
                            onExcluir: _excluirManual,
                          ),
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _adicionarManual() async {
    final descricao = TextEditingController();
    final detalhes = TextEditingController();
    final responsavel = TextEditingController();
    var data = DateTime.now();

    final salvar = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialog) => AlertDialog(
          title: const Text('Novo registro'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.calendar_today_outlined),
                  title: const Text('Data e hora'),
                  subtitle: Text(Formatters.dataHoraBr(data)),
                  onTap: () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: data,
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    if (d == null || !context.mounted) return;
                    final t = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay.fromDateTime(data),
                    );
                    setDialog(() {
                      data = DateTime(d.year, d.month, d.day, t?.hour ?? 0,
                          t?.minute ?? 0);
                    });
                  },
                ),
                TextField(
                  controller: descricao,
                  decoration: const InputDecoration(labelText: 'Descrição *'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: detalhes,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Detalhes'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: responsavel,
                  decoration: const InputDecoration(labelText: 'Responsável'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Salvar'),
            ),
          ],
        ),
      ),
    );

    if (salvar != true || descricao.text.trim().isEmpty) return;

    final repo = ref.read(obraHistoricoRepositoryProvider);
    try {
      await repo.addManual({
        'obra_id': widget.obraId,
        'tipo': 'manual',
        'descricao': descricao.text.trim(),
        'detalhes': detalhes.text.trim().isEmpty ? null : detalhes.text.trim(),
        'responsavel':
            responsavel.text.trim().isEmpty ? null : responsavel.text.trim(),
        'created_at': data.toUtc().toIso8601String(),
      });
      await repo.createNotificationsForObra(
        obraId: widget.obraId,
        obraNome: widget.obra.nome,
        tipo: 'manual',
        descricao: descricao.text.trim(),
      );
      ref.invalidate(obraHistoricoProvider(widget.obraId));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erro: $e')));
      }
    }
  }

  Future<void> _editarManual(ObraHistorico item) async {
    final descricao = TextEditingController(text: item.descricao);
    final detalhes = TextEditingController(text: item.detalhes ?? '');
    final responsavel = TextEditingController(text: item.responsavel ?? '');

    final salvar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Editar registro'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: descricao,
                decoration: const InputDecoration(labelText: 'Descrição'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: detalhes,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Detalhes'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: responsavel,
                decoration: const InputDecoration(labelText: 'Responsável'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
    if (salvar != true) return;
    await ref.read(obraHistoricoRepositoryProvider).updateManual(item.id, {
      'descricao': descricao.text.trim(),
      'detalhes': detalhes.text.trim().isEmpty ? null : detalhes.text.trim(),
      'responsavel':
          responsavel.text.trim().isEmpty ? null : responsavel.text.trim(),
    });
    ref.invalidate(obraHistoricoProvider(widget.obraId));
  }

  Future<void> _excluirManual(ObraHistorico item) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir registro'),
        content: const Text('Deseja excluir este registro do histórico?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.destructive),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (confirmar != true) return;
    await ref.read(obraHistoricoRepositoryProvider).deleteHistorico(item.id);
    ref.invalidate(obraHistoricoProvider(widget.obraId));
  }
}

class _HistoricoTile extends StatelessWidget {
  const _HistoricoTile({
    required this.item,
    required this.onEditar,
    required this.onExcluir,
  });

  final ObraHistorico item;
  final ValueChanged<ObraHistorico> onEditar;
  final ValueChanged<ObraHistorico> onExcluir;

  @override
  Widget build(BuildContext context) {
    final cfg = _tipoConfig[item.tipo] ?? _tipoConfig['manual']!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: cfg.$3.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(cfg.$2, size: 18, color: cfg.$3),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: cfg.$3.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          cfg.$1,
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: cfg.$3,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        Formatters.dataHoraBr(item.createdAt),
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.mutedForeground,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(item.descricao, style: const TextStyle(fontSize: 13.5)),
                  if (item.detalhes != null && item.detalhes!.isNotEmpty)
                    Text(
                      item.detalhes!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.mutedForeground,
                      ),
                    ),
                  if (item.responsavel != null && item.responsavel!.isNotEmpty)
                    Text(
                      'Responsável: ${item.responsavel}',
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: AppColors.mutedForeground,
                      ),
                    ),
                ],
              ),
            ),
            if (item.isManual)
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, size: 18),
                onSelected: (v) {
                  if (v == 'editar') onEditar(item);
                  if (v == 'excluir') onExcluir(item);
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'editar', child: Text('Editar')),
                  PopupMenuItem(
                    value: 'excluir',
                    child: Text('Excluir',
                        style: TextStyle(color: AppColors.destructive)),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
