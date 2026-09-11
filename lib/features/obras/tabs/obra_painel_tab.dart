import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/logic/peca_calc.dart';
import '../../../core/logic/status_config.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/progress_ring.dart';
import '../../../providers/obra_providers.dart';

/// Aba "Painel" da obra: indicadores consolidados de produção.
class ObraPainelTab extends ConsumerWidget {
  const ObraPainelTab({super.key, required this.obraId});

  final String obraId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pecasAsync = ref.watch(obrasPecasProvider(obraId));
    final insumosAsync = ref.watch(obraInsumosProvider(obraId));
    final historicoAsync = ref.watch(obraHistoricoProvider(obraId));
    final statusConfig =
        ref.watch(statusConfigProvider).value ?? StatusConfig.defaults;

    return pecasAsync.when(
      loading: () => const LoadingView(),
      error: (e, _) => Center(child: Text('Erro: $e')),
      data: (pecas) {
        final total = pecas.length;
        final contagem = <String, int>{};
        var volume = 0.0;
        var aco = 0.0;
        for (final p in pecas) {
          final key = normalizarStatus(p.status);
          contagem[key] = (contagem[key] ?? 0) + 1;
          final calc = calcularPeca(p);
          final v = calc.volume;
          volume += v;
          aco += v * (p.kgAcoPorMetro ?? 0).toDouble();
        }
        final peso = volume * 2400;
        final progresso = total == 0
            ? 0
            : (pecas.fold<double>(
                        0, (a, p) => a + statusConfig.weightOf(p.status)) /
                    total)
                .round();

        final insumosTotal = (insumosAsync.value ?? const [])
            .fold<num>(0, (a, i) => a + i.valorTotal);
        final historico = historicoAsync.value ?? const [];

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            Row(
              children: [
                ProgressRing(
                  value: progresso.toDouble(),
                  size: 96,
                  strokeWidth: 10,
                  color: AppColors.primary,
                  label: '$progresso%',
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Progresso geral',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text('$total peças na obra',
                          style: const TextStyle(
                              color: AppColors.mutedForeground)),
                      const SizedBox(height: 8),
                      Text(
                        'Volume: ${Formatters.numero(volume, 2)} m³',
                        style: const TextStyle(fontSize: 12.5),
                      ),
                      Text(
                        'Aço: ${Formatters.numero(aco, 0)} kg · Peso: ${Formatters.numero(peso, 0)} kg',
                        style: const TextStyle(fontSize: 12.5),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Text('Peças por status',
                style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: statusOrdem.map((s) {
                    final n = contagem[s] ?? 0;
                    final pct = total == 0 ? 0.0 : n / total;
                    final cor = statusConfig.colorOf(s);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 92,
                            child: Text(statusLabel(s),
                                style: const TextStyle(fontSize: 12.5)),
                          ),
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(999),
                              child: LinearProgressIndicator(
                                value: pct,
                                minHeight: 10,
                                backgroundColor: AppColors.muted,
                                color: cor,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 36,
                            child: Text('$n',
                                textAlign: TextAlign.right,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: ListTile(
                leading: const Icon(Icons.receipt_long_outlined,
                    color: AppColors.primary),
                title: const Text('Insumos lançados'),
                trailing: Text(
                  Formatters.moeda(insumosTotal),
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 15),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Atividade recente',
                style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            if (historico.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Sem registros de histórico.',
                      style: TextStyle(color: AppColors.mutedForeground)),
                ),
              )
            else
              Card(
                child: Column(
                  children: historico.take(8).map((h) {
                    return ListTile(
                      dense: true,
                      leading: const Icon(Icons.history, size: 18),
                      title: Text(h.descricao,
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text(
                        h.createdAt != null
                            ? Formatters.dataHoraBr(h.createdAt)
                            : '',
                        style: const TextStyle(fontSize: 11.5),
                      ),
                    );
                  }).toList(),
                ),
              ),
          ],
        );
      },
    );
  }
}
