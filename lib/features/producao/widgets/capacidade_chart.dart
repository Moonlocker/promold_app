import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/logic/painel_calc.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../models/capacidade.dart';
import '../../../models/producao_indicadores.dart';
import '../../../providers/capacidade_providers.dart';
import 'producao_chart.dart';

/// Gráfico "Capacidade vs Planejado" por semana (padrão do webapp).
class CapacidadeChart extends ConsumerStatefulWidget {
  const CapacidadeChart({super.key});

  @override
  ConsumerState<CapacidadeChart> createState() => _CapacidadeChartState();
}

class _CapacidadeChartState extends ConsumerState<CapacidadeChart> {
  int _offset = 0;

  @override
  Widget build(BuildContext context) {
    final inicio = inicioDaSemana(DateTime.now())
        .add(Duration(days: _offset * 7));
    final fim = inicio.add(const Duration(days: 6));
    final async = ref.watch(capacidadeSemanaProvider(inicio));
    final dias = async.value ?? const <CapacidadeDia>[];
    final totalExcedido = dias.where((d) => d.excedido).length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.factory_outlined,
                    size: 18, color: AppColors.primary),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Capacidade vs Planejado',
                    style:
                        TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                ),
                if (totalExcedido > 0)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.destructive.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '$totalExcedido dia(s) excedido(s)',
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.destructive,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              '${Formatters.dataBr(inicio)} – ${Formatters.dataBr(fim)}',
              style: const TextStyle(
                  fontSize: 11.5, color: AppColors.mutedForeground),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                IconButton(
                  onPressed: () => setState(() => _offset -= 1),
                  icon: const Icon(Icons.chevron_left),
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Semana anterior',
                ),
                TextButton(
                  onPressed: _offset == 0
                      ? null
                      : () => setState(() => _offset = 0),
                  child: const Text('Hoje'),
                ),
                IconButton(
                  onPressed: () => setState(() => _offset += 1),
                  icon: const Icon(Icons.chevron_right),
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Próxima semana',
                ),
                const Spacer(),
                const _Legenda(cor: AppColors.info, texto: 'Planejado'),
                const SizedBox(width: 12),
                const _Legenda(cor: AppColors.success, texto: 'Capacidade'),
              ],
            ),
            const SizedBox(height: 4),
            if (async.isLoading)
              const SizedBox(
                height: 200,
                child: Center(child: CircularProgressIndicator()),
              )
            else
              ProducaoDiariaChart(
                dias: dias.map(_toDia).toList(),
                corProduzido: AppColors.info,
                corPlanejado: AppColors.success,
                height: 220,
              ),
          ],
        ),
      ),
    );
  }

  ProducaoDia _toDia(CapacidadeDia d) => ProducaoDia(
        date: Formatters.iso(d.data),
        label: d.label,
        pecas: d.planejado,
        planejado: d.capacidade.round(),
        concreto: 0,
        aco: 0,
        concretoPlan: 0,
        acoPlan: 0,
      );
}

class _Legenda extends StatelessWidget {
  const _Legenda({required this.cor, required this.texto});

  final Color cor;
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: cor, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(texto, style: const TextStyle(fontSize: 11)),
      ],
    );
  }
}
