import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/peca_status_chip.dart';
import '../../../providers/obra_providers.dart';
import '../../../providers/planejamento_providers.dart';
import '../../../providers/supabase_providers.dart';
import '../widgets/obra_peca_edit_sheet.dart';
import '../../planejamento/widgets/planejamento_historico_sheet.dart';
import '../../planejamento/widgets/planejar_sheet.dart';

/// Aba "Planejamento" da obra: armação, produção e montagem da semana.
class ObraPlanejamentoTab extends ConsumerStatefulWidget {
  const ObraPlanejamentoTab({super.key, required this.obraId});

  final String obraId;

  @override
  ConsumerState<ObraPlanejamentoTab> createState() =>
      _ObraPlanejamentoTabState();
}

class _ObraPlanejamentoTabState extends ConsumerState<ObraPlanejamentoTab> {
  String _tipo = 'armacao';
  DateTime _semana = _inicioSemana(DateTime.now());

  static DateTime _inicioSemana(DateTime d) {
    final base = DateTime(d.year, d.month, d.day);
    return base.subtract(Duration(days: base.weekday % 7));
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(obraPlanoProvider((widget.obraId, _tipo, _semana)));
    final fim = _semana.add(const Duration(days: 6));
    final isMontagem = _tipo == 'montagem';

    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: isMontagem
          ? null
          : FloatingActionButton.extended(
              onPressed: _adicionar,
              icon: const Icon(Icons.add),
              label: const Text('Planejar'),
            ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'armacao', label: Text('Armação')),
                ButtonSegment(value: 'producao', label: Text('Produção')),
                ButtonSegment(value: 'montagem', label: Text('Montagem')),
              ],
              selected: {_tipo},
              onSelectionChanged: (s) => setState(() => _tipo = s.first),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => setState(
                      () => _semana = _semana.subtract(const Duration(days: 7))),
                  icon: const Icon(Icons.chevron_left),
                ),
                Expanded(
                  child: Text(
                    'Semana de ${Formatters.dataBr(_semana)} a ${Formatters.dataBr(fim)}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
                IconButton(
                  onPressed: () => setState(
                      () => _semana = _semana.add(const Duration(days: 7))),
                  icon: const Icon(Icons.chevron_right),
                ),
                IconButton(
                  tooltip: 'Histórico e ocorrências',
                  onPressed: () => showPlanejamentoHistoricoSheet(
                    context,
                    obraId: widget.obraId,
                    tipo: _tipo,
                  ),
                  icon: const Icon(Icons.history),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: async.when(
              loading: () => const LoadingView(),
              error: (e, _) => Center(child: Text('Erro: $e')),
              data: (itens) {
                if (itens.isEmpty) {
                  return const EmptyState(
                    icon: Icons.event_available_outlined,
                    title: 'Nada planejado',
                    message: 'Nenhum item planejado nesta semana.',
                  );
                }
                // Agrupa por dia (data início).
                final grupos = <String, List<ObraPlanoItem>>{};
                for (final it in itens) {
                  grupos.putIfAbsent(it.dataInicio, () => []).add(it);
                }
                final chaves = grupos.keys.toList()..sort();
                return RefreshIndicator(
                  onRefresh: () async => ref.invalidate(
                      obraPlanoProvider((widget.obraId, _tipo, _semana))),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                    children: [
                      for (final chave in chaves) ...[
                        Text(
                          Formatters.dataBr(DateTime.tryParse(chave)),
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 13),
                        ),
                        const SizedBox(height: 6),
                        Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: Column(
                            children: grupos[chave]!
                                .map((it) => _ItemLinha(
                                      item: it,
                                      onTap: () => _editar(it),
                                      onRemover: () => _remover(it),
                                    ))
                                .toList(),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _adicionar() async {
    final ok = await showPlanejarSheet(
      context,
      ref,
      tipo: _tipo,
      diaInicial: DateTime.now(),
      obraIdInicial: widget.obraId,
    );
    if (ok == true) {
      ref.invalidate(obraPlanoProvider((widget.obraId, _tipo, _semana)));
    }
  }

  Future<void> _editar(ObraPlanoItem item) async {
    if (item.obraPecaId == null) return;
    final pecas = await ref.read(obrasPecasProvider(widget.obraId).future);
    final alvo = pecas.where((p) => p.id == item.obraPecaId).firstOrNull;
    if (alvo == null || !mounted) return;
    final ok = await showPecaEditSheet(context, ref, peca: alvo, todas: pecas);
    if (ok == true) {
      ref.invalidate(obrasPecasProvider(widget.obraId));
      ref.invalidate(obraPlanoProvider((widget.obraId, _tipo, _semana)));
    }
  }

  Future<void> _remover(ObraPlanoItem item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remover do planejamento'),
        content: Text('Remover ${item.identificador} do planejamento?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.destructive),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remover'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    if (item.montagem) {
      await ref.read(producaoRepositoryProvider).removerMontagem(item.planId);
    } else {
      await ref.read(producaoRepositoryProvider).removerPlanejamento(item.planId);
    }
    ref.invalidate(obraPlanoProvider((widget.obraId, _tipo, _semana)));
  }
}

class _ItemLinha extends StatelessWidget {
  const _ItemLinha({
    required this.item,
    required this.onTap,
    required this.onRemover,
  });

  final ObraPlanoItem item;
  final VoidCallback onTap;
  final VoidCallback onRemover;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: item.obraPecaId != null ? onTap : null,
      title: Text(item.identificador,
          style: const TextStyle(
              fontFamily: 'monospace', fontWeight: FontWeight.w600)),
      subtitle: Text(item.pecaNome,
          maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!item.montagem) PecaStatusChip(status: item.status, compact: true),
          IconButton(
            icon: const Icon(Icons.delete_outline,
                size: 18, color: AppColors.destructive),
            onPressed: onRemover,
          ),
        ],
      ),
    );
  }
}
