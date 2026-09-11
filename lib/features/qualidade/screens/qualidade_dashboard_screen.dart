import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/logic/qc_engine.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../models/qc.dart';
import '../../../providers/qualidade_providers.dart';
import '../widgets/qualidade_badge.dart';

/// Dashboard de Qualidade: indicadores de lotes, CPs e ensaios.
class QualidadeDashboardScreen extends ConsumerWidget {
  const QualidadeDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lotesAsync = ref.watch(qcLotesProvider);
    final cpsAsync = ref.watch(qcCpsProvider);
    final ensaiosAsync = ref.watch(qcEnsaiosProvider);

    if (lotesAsync.isLoading || cpsAsync.isLoading || ensaiosAsync.isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Controle de Qualidade')),
        body: const LoadingView(),
      );
    }

    final lotes = lotesAsync.value ?? const <QcLote>[];
    final cps = cpsAsync.value ?? const <QcCorpoProva>[];
    final ensaios = ensaiosAsync.value ?? const <QcEnsaio>[];

    final status = calcularStatusLotes(lotes: lotes, cps: cps, ensaios: ensaios);
    var aprov = 0, reprov = 0, aguard = 0;
    status.forEach((_, s) {
      if (s == QcStatus.aprovado) {
        aprov++;
      } else if (s == QcStatus.reprovado) {
        reprov++;
      } else {
        aguard++;
      }
    });

    final hoje = Formatters.hojeBr();
    final cpEnsaiados = ensaios.map((e) => e.corpoProvaId).toSet();
    final cpsAguardando = cps
        .where((c) =>
            !cpEnsaiados.contains(c.id) &&
            (c.dataPrevistaRompimento ?? '').compareTo(hoje) >= 0)
        .length;
    final cpsVencidos = cps
        .where((c) =>
            !cpEnsaiados.contains(c.id) &&
            (c.dataPrevistaRompimento ?? '').isNotEmpty &&
            c.dataPrevistaRompimento!.compareTo(hoje) < 0)
        .length;

    final resistencias = ensaios.map((e) => e.resistenciaMpa).toList();
    final mediaResist = resistencias.isEmpty
        ? 0.0
        : resistencias.reduce((a, b) => a + b) / resistencias.length;
    final aprovEnsaios = ensaios.where((e) => e.aprovado == true).length;
    final taxaAprov =
        ensaios.isEmpty ? 0 : ((aprovEnsaios / ensaios.length) * 100).round();

    return Scaffold(
      appBar: AppBar(title: const Text('Controle de Qualidade')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(qcLotesProvider);
          ref.invalidate(qcCpsProvider);
          ref.invalidate(qcEnsaiosProvider);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.7,
              children: [
                _Stat('Lotes', lotes.length, AppColors.primary,
                    Icons.science_outlined),
                _Stat('Aprovados', aprov, AppColors.success,
                    Icons.check_circle_outline),
                _Stat('Reprovados', reprov, AppColors.destructive,
                    Icons.cancel_outlined),
                _Stat('Aguardando', aguard, AppColors.warning,
                    Icons.schedule_outlined),
                _Stat('CPs moldados', cps.length, AppColors.info,
                    Icons.biotech_outlined),
                _Stat('CPs a romper', cpsAguardando, AppColors.warning,
                    Icons.hourglass_empty),
                _Stat('CPs vencidos', cpsVencidos, AppColors.destructive,
                    Icons.warning_amber_outlined),
                _Stat('Ensaios', ensaios.length, AppColors.success,
                    Icons.fact_check_outlined),
              ],
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Resistência média',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(
                      '${mediaResist.toStringAsFixed(1)} MPa',
                      style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary),
                    ),
                    Text(
                      'Taxa de aprovação dos ensaios: $taxaAprov%',
                      style: const TextStyle(
                          fontSize: 12.5,
                          color: AppColors.mutedForeground),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('FCK por lote',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 12),
                    if (lotes.isEmpty)
                      const Text('Sem lotes cadastrados',
                          style: TextStyle(
                              color: AppColors.mutedForeground))
                    else
                      ...lotes.take(12).map((l) {
                        final maxFck = lotes
                            .map((x) => x.fckMpa)
                            .fold<double>(1, (a, b) => a > b ? a : b);
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(l.codigo,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            fontSize: 12.5)),
                                  ),
                                  Text('${l.fckMpa.toStringAsFixed(1)} MPa',
                                      style: const TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w600)),
                                ],
                              ),
                              const SizedBox(height: 4),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(999),
                                child: LinearProgressIndicator(
                                  value: l.fckMpa / maxFck,
                                  minHeight: 6,
                                  backgroundColor: AppColors.muted,
                                  color: AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.valor, this.cor, this.icon);

  final String label;
  final int valor;
  final Color cor;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: cor),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(label,
                      style: const TextStyle(
                          fontSize: 11.5, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            const Spacer(),
            Text('$valor',
                style: TextStyle(
                    fontSize: 22, fontWeight: FontWeight.w700, color: cor)),
          ],
        ),
      ),
    );
  }
}
