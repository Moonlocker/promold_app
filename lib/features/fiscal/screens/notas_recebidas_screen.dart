import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/utils/formatters.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../models/nota_fiscal.dart';
import '../../../providers/fiscal_providers.dart';
import '../../../providers/supabase_providers.dart';

/// Lista de notas fiscais recebidas (NFe emitidas contra a organização).
class NotasRecebidasScreen extends ConsumerStatefulWidget {
  const NotasRecebidasScreen({super.key});

  @override
  ConsumerState<NotasRecebidasScreen> createState() =>
      _NotasRecebidasScreenState();
}

class _NotasRecebidasScreenState extends ConsumerState<NotasRecebidasScreen> {
  String _busca = '';
  String _manifesto = 'todos';
  bool _syncing = false;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(notasRecebidasProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notas Recebidas'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Sincronizar',
            onPressed: _syncing ? null : _sincronizar,
          ),
        ],
      ),
      body: async.when(
        loading: () => const LoadingView(),
        error: (e, _) => Center(child: Text('Erro: $e')),
        data: (notas) {
          final filtradas = notas.where((n) {
            if (_manifesto == 'pendente' && n.manifestoStatus != null) {
              return false;
            }
            if (_manifesto != 'todos' &&
                _manifesto != 'pendente' &&
                n.manifestoStatus != _manifesto) {
              return false;
            }
            final q = _busca.toLowerCase();
            return (n.emitenteNome ?? '').toLowerCase().contains(q) ||
                n.chaveNfe.contains(q) ||
                (n.numero ?? '').contains(q);
          }).toList();

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(notasRecebidasProvider),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              children: [
                TextField(
                  onChanged: (v) => setState(() => _busca = v),
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search, size: 20),
                    hintText: 'Buscar por emitente, número ou chave...',
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: _manifesto,
                  isDense: true,
                  decoration: const InputDecoration(
                      labelText: 'Manifesto', isDense: true),
                  items: const [
                    DropdownMenuItem(value: 'todos', child: Text('Todos')),
                    DropdownMenuItem(
                        value: 'pendente', child: Text('Não manifestadas')),
                    DropdownMenuItem(value: 'ciencia', child: Text('Ciência')),
                    DropdownMenuItem(
                        value: 'confirmacao', child: Text('Confirmação')),
                    DropdownMenuItem(
                        value: 'desconhecimento',
                        child: Text('Desconhecimento')),
                    DropdownMenuItem(
                        value: 'nao_realizada', child: Text('Não realizada')),
                  ],
                  onChanged: (v) => setState(() => _manifesto = v ?? 'todos'),
                ),
                const SizedBox(height: 12),
                if (filtradas.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 48),
                    child: EmptyState(
                      icon: Icons.move_to_inbox_outlined,
                      title: 'Nenhuma nota recebida',
                      message: 'Toque em sincronizar para buscar notas.',
                    ),
                  )
                else
                  ...filtradas.map((n) => _NotaRecebidaCard(
                        nota: n,
                        onChanged: () => ref.invalidate(notasRecebidasProvider),
                      )),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _sincronizar() async {
    setState(() => _syncing = true);
    try {
      final data = await ref.read(fiscalRepositoryProvider).sincronizarRecebidas();
      if (data['status'] == 'pendente_integracao') {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${data['message'] ?? 'Integração não configurada'}')),
          );
        }
      } else {
        ref.invalidate(notasRecebidasProvider);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${data['total'] ?? 0} notas sincronizadas')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'.replaceFirst('Exception: ', ''))),
        );
      }
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }
}

class _NotaRecebidaCard extends ConsumerWidget {
  const _NotaRecebidaCard({required this.nota, required this.onChanged});

  final NotaFiscalRecebida nota;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        title: Text(nota.emitenteNome ?? '—',
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          '${nota.emitenteCnpj ?? ''}\n'
          'Nº ${nota.numero ?? '—'}/${nota.serie ?? '—'} · '
          '${nota.dataEmissao != null ? Formatters.dataHoraBr(DateTime.tryParse(nota.dataEmissao!)) : '—'} · '
          '${Formatters.moeda(nota.valorTotal ?? 0)}'
          '${nota.manifestoStatus != null ? ' · ${nota.manifestoStatus}' : ''}',
          style: const TextStyle(fontSize: 12),
        ),
        isThreeLine: true,
        trailing: PopupMenuButton<String>(
          onSelected: (v) async {
            switch (v) {
              case 'xml':
                if (nota.xmlUrl != null) {
                  await launchUrl(Uri.parse(nota.xmlUrl!));
                }
              case 'danfe':
                if (nota.danfeUrl != null) {
                  await launchUrl(Uri.parse(nota.danfeUrl!));
                }
              case 'manifestar':
                await _manifestar(context, ref);
            }
          },
          itemBuilder: (_) => [
            if (nota.xmlUrl != null)
              const PopupMenuItem(value: 'xml', child: Text('Abrir XML')),
            if (nota.danfeUrl != null)
              const PopupMenuItem(value: 'danfe', child: Text('Abrir DANFE')),
            const PopupMenuItem(
                value: 'manifestar', child: Text('Manifestar')),
          ],
        ),
      ),
    );
  }

  Future<void> _manifestar(BuildContext context, WidgetRef ref) async {
    String tipo = 'ciencia';
    final justificativa = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Manifestar NFe'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(nota.chaveNfe,
                  style: const TextStyle(
                      fontFamily: 'monospace', fontSize: 11)),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: tipo,
                decoration: const InputDecoration(labelText: 'Tipo'),
                items: const [
                  DropdownMenuItem(
                      value: 'ciencia', child: Text('Ciência da Operação')),
                  DropdownMenuItem(
                      value: 'confirmacao',
                      child: Text('Confirmação da Operação')),
                  DropdownMenuItem(
                      value: 'desconhecimento',
                      child: Text('Desconhecimento da Operação')),
                  DropdownMenuItem(
                      value: 'nao_realizada',
                      child: Text('Operação Não Realizada')),
                ],
                onChanged: (v) => setState(() => tipo = v ?? 'ciencia'),
              ),
              if (tipo == 'desconhecimento' || tipo == 'nao_realizada') ...[
                const SizedBox(height: 12),
                TextField(
                  controller: justificativa,
                  decoration: const InputDecoration(
                      labelText: 'Justificativa (mín. 15 caracteres)'),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Enviar'),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    if ((tipo == 'desconhecimento' || tipo == 'nao_realizada') &&
        justificativa.text.trim().length < 15) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Justificativa muito curta')),
        );
      }
      return;
    }
    try {
      final res = await ref.read(fiscalRepositoryProvider).manifestar(
            chave: nota.chaveNfe,
            tipo: tipo,
            justificativa: justificativa.text.trim(),
          );
      onChanged();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(res['ok'] == true
                  ? 'Manifesto enviado'
                  : '${res['error'] ?? 'Falha no manifesto'}')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'.replaceFirst('Exception: ', ''))),
        );
      }
    }
  }
}
