import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/auth_providers.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../models/nota_fiscal.dart';
import '../../../providers/fiscal_providers.dart';
import '../../../providers/supabase_providers.dart';
import '../widgets/nota_detalhe_sheet.dart';
import 'emitir_nota_screen.dart';

/// Lista de notas fiscais emitidas.
class NotasEmitidasScreen extends ConsumerStatefulWidget {
  const NotasEmitidasScreen({super.key});

  @override
  ConsumerState<NotasEmitidasScreen> createState() =>
      _NotasEmitidasScreenState();
}

class _NotasEmitidasScreenState extends ConsumerState<NotasEmitidasScreen> {
  String _busca = '';
  String _status = 'todos';

  Color _statusCor(String s) => switch (s) {
        'autorizada' => AppColors.success,
        'processando' => AppColors.info,
        'rejeitada' || 'denegada' || 'erro' => AppColors.destructive,
        'cancelada' => AppColors.warning,
        _ => AppColors.mutedForeground,
      };

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(notasFiscaisProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Notas Emitidas')),
      floatingActionButton: ref.podeCriar('fiscal-emitir')
          ? FloatingActionButton.extended(
              onPressed: () async {
                final ok = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(builder: (_) => const EmitirNotaScreen()),
                );
                if (ok == true) ref.invalidate(notasFiscaisProvider);
              },
              icon: const Icon(Icons.add),
              label: const Text('Emitir Nota'),
            )
          : null,
      body: async.when(
        loading: () => const LoadingView(),
        error: (e, _) => Center(child: Text('Erro: $e')),
        data: (notas) {
          final statusUnicos = notas.map((n) => n.status).toSet().toList();
          final filtradas = notas.where((n) {
            if (_status != 'todos' && n.status != _status) return false;
            final q = _busca.toLowerCase();
            return (n.clienteNome ?? '').toLowerCase().contains(q) ||
                '${n.numero ?? ''}'.contains(q) ||
                (n.chaveAcesso ?? '').contains(q);
          }).toList();

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(notasFiscaisProvider),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
              children: [
                TextField(
                  onChanged: (v) => setState(() => _busca = v),
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search, size: 20),
                    hintText: 'Buscar por cliente, nÃºmero, chave...',
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: _status,
                  isDense: true,
                  decoration:
                      const InputDecoration(labelText: 'Status', isDense: true),
                  items: [
                    const DropdownMenuItem(
                        value: 'todos', child: Text('Todos')),
                    ...statusUnicos.map((s) => DropdownMenuItem(
                          value: s,
                          child: Text(s),
                        )),
                  ],
                  onChanged: (v) => setState(() => _status = v ?? 'todos'),
                ),
                const SizedBox(height: 12),
                if (filtradas.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 48),
                    child: EmptyState(
                      icon: Icons.description_outlined,
                      title: 'Nenhuma nota encontrada',
                    ),
                  )
                else
                  ...filtradas.map((n) => _NotaCard(
                        nota: n,
                        statusCor: _statusCor(n.status),
                        onChanged: () => ref.invalidate(notasFiscaisProvider),
                      )),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _NotaCard extends ConsumerWidget {
  const _NotaCard({
    required this.nota,
    required this.statusCor,
    required this.onChanged,
  });

  final NotaFiscal nota;
  final Color statusCor;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        onTap: () => showNotaDetalheSheet(context, nota: nota),
        title: Row(
          children: [
            Expanded(
              child: Text(
                nota.numero != null
                    ? 'NÂº ${nota.numero}/${nota.serie}'
                    : '(rascunho)',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: statusCor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                nota.status,
                style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w600, color: statusCor),
              ),
            ),
          ],
        ),
        subtitle: Text(
          '${nota.clienteNome ?? 'â€”'} Â· ${nota.tipoDocumento.toUpperCase()} Â· ${nota.ambiente}\n'
          '${nota.dataEmissao != null ? Formatters.dataHoraBr(DateTime.tryParse(nota.dataEmissao!)) : 'â€”'} Â· ${Formatters.moeda(nota.valorTotal ?? 0)}',
          style: const TextStyle(fontSize: 12),
        ),
        isThreeLine: true,
        trailing: PopupMenuButton<String>(
          onSelected: (v) => _acao(context, ref, v),
          itemBuilder: (_) => [
            if (nota.danfeUrl != null)
              const PopupMenuItem(value: 'danfe', child: Text('Baixar DANFE')),
            if (nota.xmlUrl != null)
              const PopupMenuItem(value: 'xml', child: Text('Baixar XML')),
            if (nota.chaveAcesso != null)
              const PopupMenuItem(
                  value: 'chave', child: Text('Copiar chave de acesso')),
            const PopupMenuItem(
                value: 'consultar', child: Text('Consultar status')),
            if (ref.podeEditar('fiscal-notas') && nota.status == 'rascunho')
              const PopupMenuItem(value: 'emitir', child: Text('Emitir nota')),
            if (ref.podeEditar('fiscal-notas') && nota.status == 'autorizada') ...[
              const PopupMenuItem(
                  value: 'cce', child: Text('Carta de correÃ§Ã£o')),
              const PopupMenuItem(
                value: 'cancelar',
                child: Text('Cancelar nota',
                    style: TextStyle(color: AppColors.destructive)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _acao(BuildContext context, WidgetRef ref, String acao) async {
    final repo = ref.read(fiscalRepositoryProvider);
    switch (acao) {
      case 'danfe':
        await launchUrl(Uri.parse(nota.danfeUrl!));
      case 'xml':
        await launchUrl(Uri.parse(nota.xmlUrl!));
      case 'chave':
        await Clipboard.setData(ClipboardData(text: nota.chaveAcesso!));
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Chave copiada')),
          );
        }
      case 'consultar':
        await _executar(context, () => repo.acaoNfe('consultar', {'nota_id': nota.id}),
            'Status sincronizado');
      case 'emitir':
        await _executar(context, () => repo.acaoNfe('emitir', {'nota_id': nota.id}),
            'Nota enviada para emissÃ£o');
      case 'cce':
        final texto = await _pedirTexto(
          context,
          titulo: 'Carta de correÃ§Ã£o',
          label: 'Texto da correÃ§Ã£o',
        );
        if (texto != null && texto.trim().length >= 15 && context.mounted) {
          await _executar(
            context,
            () => repo.acaoNfe(
                'carta_correcao', {'nota_id': nota.id, 'texto': texto}),
            'Carta de correÃ§Ã£o enviada',
          );
        } else if (texto != null && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('MÃ­nimo de 15 caracteres')),
          );
        }
      case 'cancelar':
        final motivo = await _pedirTexto(
          context,
          titulo: 'Cancelar nota',
          label: 'Motivo (mÃ­n. 15 caracteres)',
        );
        if (motivo != null && motivo.trim().length >= 15 && context.mounted) {
          await _executar(
            context,
            () => repo.acaoNfe(
                'cancelar', {'nota_id': nota.id, 'motivo': motivo}),
            'Cancelamento solicitado',
          );
        } else if (motivo != null && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('MÃ­nimo de 15 caracteres')),
          );
        }
    }
  }

  Future<void> _executar(
    BuildContext context,
    Future<Map<String, dynamic>> Function() fn,
    String sucesso,
  ) async {
    try {
      await fn();
      onChanged();
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(sucesso)));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'.replaceFirst('Exception: ', ''))),
        );
      }
    }
  }

  Future<String?> _pedirTexto(
    BuildContext context, {
    required String titulo,
    required String label,
  }) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(titulo),
        content: TextField(
          controller: controller,
          maxLines: 4,
          decoration: InputDecoration(labelText: label),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Enviar'),
          ),
        ],
      ),
    );
  }
}
