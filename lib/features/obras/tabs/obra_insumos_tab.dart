import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../models/obra_historico.dart';
import '../../../providers/obra_providers.dart';
import '../../../providers/supabase_providers.dart';

/// Aba "Insumos" da obra (tabela `obras_insumos`).
class ObraInsumosTab extends ConsumerStatefulWidget {
  const ObraInsumosTab({super.key, required this.obraId});

  final String obraId;

  @override
  ConsumerState<ObraInsumosTab> createState() => _ObraInsumosTabState();
}

class _ObraInsumosTabState extends ConsumerState<ObraInsumosTab> {
  final _busca = TextEditingController();

  @override
  void dispose() {
    _busca.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final insumosAsync = ref.watch(obraInsumosProvider(widget.obraId));

    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _editar(null),
        icon: const Icon(Icons.add),
        label: const Text('Insumo'),
      ),
      body: insumosAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erro: $e')),
        data: (insumos) {
          final termo = _busca.text.trim().toLowerCase();
          final filtrados = insumos.where((i) {
            if (termo.isEmpty) return true;
            return i.descricao.toLowerCase().contains(termo) ||
                (i.codigo ?? '').toLowerCase().contains(termo);
          }).toList();
          final total = filtrados.fold<num>(0, (a, i) => a + i.valorTotal);

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
                        hintText: 'Buscar insumo',
                        prefixIcon: Icon(Icons.search),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text('${filtrados.length} insumo(s)',
                            style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.mutedForeground)),
                        const Spacer(),
                        Text('Total: ${Formatters.moeda(total)}',
                            style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: filtrados.isEmpty
                    ? const EmptyState(
                        icon: Icons.inventory_outlined,
                        title: 'Nenhum insumo',
                        message: 'Cadastre os insumos utilizados na obra.',
                      )
                    : RefreshIndicator(
                        onRefresh: () async => ref
                            .invalidate(obraInsumosProvider(widget.obraId)),
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                          itemCount: filtrados.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 8),
                          itemBuilder: (_, index) {
                            final insumo = filtrados[index];
                            return Card(
                              child: ListTile(
                                title: Text(insumo.descricao),
                                subtitle: Text(
                                  '${insumo.codigo ?? '—'} · ${insumo.quantidade} ${insumo.unidade}'
                                  '${insumo.valorUnitario != null ? ' · ${Formatters.moeda(insumo.valorUnitario!)}' : ''}',
                                  style: const TextStyle(fontSize: 12),
                                ),
                                trailing: Text(
                                  Formatters.moeda(insumo.valorTotal),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700),
                                ),
                                onTap: () => _editar(insumo),
                                onLongPress: () => _excluir(insumo),
                              ),
                            );
                          },
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _editar(ObraInsumo? insumo) async {
    final descricao = TextEditingController(text: insumo?.descricao ?? '');
    final codigo = TextEditingController(text: insumo?.codigo ?? '');
    final quantidade = TextEditingController(
        text: insumo?.quantidade.toString() ?? '1');
    final unidade = TextEditingController(text: insumo?.unidade ?? 'un');
    final valor = TextEditingController(
        text: insumo?.valorUnitario?.toString() ?? '');
    final observacoes = TextEditingController(text: insumo?.observacoes ?? '');

    final salvar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(insumo == null ? 'Novo insumo' : 'Editar insumo'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: descricao,
                decoration: const InputDecoration(labelText: 'Descrição *'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: codigo,
                decoration: const InputDecoration(labelText: 'Código'),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: quantidade,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      decoration: const InputDecoration(labelText: 'Qtd.'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: unidade,
                      decoration: const InputDecoration(labelText: 'Unidade'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: valor,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration:
                    const InputDecoration(labelText: 'Valor unitário (R\$)'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: observacoes,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Observações'),
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
    if (salvar != true || descricao.text.trim().isEmpty) return;

    String? nz(String v) => v.trim().isEmpty ? null : v.trim();
    await ref.read(obraInsumosRepositoryProvider).save({
      'id': insumo?.id,
      'obra_id': widget.obraId,
      'descricao': descricao.text.trim(),
      'codigo': nz(codigo.text),
      'quantidade': double.tryParse(quantidade.text.replaceAll(',', '.')) ?? 1,
      'unidade': unidade.text.trim().isEmpty ? 'un' : unidade.text.trim(),
      'valor_unitario':
          double.tryParse(valor.text.replaceAll(',', '.')),
      'observacoes': nz(observacoes.text),
      'origem': insumo?.origem ?? 'manual',
    });
    ref.invalidate(obraInsumosProvider(widget.obraId));
  }

  Future<void> _excluir(ObraInsumo insumo) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir insumo'),
        content: Text('Deseja excluir "${insumo.descricao}"?'),
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
    await ref.read(obraInsumosRepositoryProvider).delete(insumo.id);
    ref.invalidate(obraInsumosProvider(widget.obraId));
  }
}
