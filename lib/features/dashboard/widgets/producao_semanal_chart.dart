import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/logic/peca_calc.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../models/obra_peca.dart';
import '../../../models/producao_indicadores.dart';
import '../../../providers/dashboard_providers.dart';
import '../../../providers/obra_providers.dart';
import '../../producao/widgets/producao_chart.dart';

/// Gráfico "Produção Semanal" do Dashboard (realizado x planejado), com
/// navegação por semana e detalhamento por dia.
class ProducaoSemanalChart extends ConsumerStatefulWidget {
  const ProducaoSemanalChart({super.key});

  @override
  ConsumerState<ProducaoSemanalChart> createState() =>
      _ProducaoSemanalChartState();
}

class _ProducaoSemanalChartState extends ConsumerState<ProducaoSemanalChart> {
  int _offset = 0;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(dashboardSemanaProvider(_offset));
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: async.when(
          loading: () => const SizedBox(
            height: 220,
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => Text('Erro: $e',
              style: const TextStyle(color: AppColors.mutedForeground)),
          data: (semana) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Produção Semanal',
                      style:
                          TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Semana anterior',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => setState(() => _offset -= 1),
                    icon: const Icon(Icons.chevron_left),
                  ),
                  TextButton(
                    onPressed:
                        _offset == 0 ? null : () => setState(() => _offset = 0),
                    child: const Text('Hoje'),
                  ),
                  IconButton(
                    tooltip: 'Próxima semana',
                    visualDensity: VisualDensity.compact,
                    onPressed: _offset >= 0
                        ? null
                        : () => setState(() => _offset += 1),
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
              Text(
                '${Formatters.dataBr(semana.inicio)} – ${Formatters.dataBr(semana.fim)}',
                style: const TextStyle(
                    fontSize: 11.5, color: AppColors.mutedForeground),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _Totais(
                      label: 'Semana anterior',
                      valor: semana.totalAnterior,
                      cor: AppColors.mutedForeground,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _Totais(
                      label: 'Realizado',
                      valor: semana.totalAtual,
                      cor: AppColors.success,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _Totais(
                      label: 'Planejado',
                      valor: semana.totalPlanejado,
                      cor: AppColors.warning,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: const [
                  _Legenda(cor: AppColors.success, texto: 'Produzido'),
                  SizedBox(width: 14),
                  _Legenda(cor: AppColors.primary, texto: 'Planejado'),
                ],
              ),
              const SizedBox(height: 8),
              ProducaoDiariaChart(
                dias: semana.dias
                    .map((d) => ProducaoDia(
                          date: Formatters.iso(d.data),
                          label: d.diaSemana,
                          pecas: d.produzidoAtual,
                          planejado: d.planejado,
                          concreto: 0,
                          aco: 0,
                          concretoPlan: 0,
                          acoPlan: 0,
                        ))
                    .toList(),
                onDayTap: (d) => _abrirDia(context, d.date),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _abrirDia(BuildContext context, String iso) {
    final pecas = ref.read(todasPecasResumoProvider).value ?? const [];
    final dia = DateTime.tryParse(iso);
    final doDia = pecas
        .where((p) =>
            p.dataConcretagem != null &&
            p.status != 'pendente' &&
            dia != null &&
            p.dataConcretagem!.year == dia.year &&
            p.dataConcretagem!.month == dia.month &&
            p.dataConcretagem!.day == dia.day)
        .toList();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.7,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Produzidas em ${Formatters.dataBr(dia)} · ${doDia.length}',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: doDia.isEmpty
                  ? const Center(
                      child: Text('Nenhuma peça produzida neste dia.',
                          style:
                              TextStyle(color: AppColors.mutedForeground)),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: doDia.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, i) => _PecaTile(peca: doDia[i]),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PecaTile extends StatelessWidget {
  const _PecaTile({required this.peca});

  final ObraPeca peca;

  @override
  Widget build(BuildContext context) {
    final calc = calcularPeca(peca);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (peca.identificador.isNotEmpty)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.muted,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(peca.identificador,
                      style: const TextStyle(
                          fontSize: 11, fontFamily: 'monospace')),
                ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  peca.pecaCatalogo?.nome ?? 'Peça',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 13.5, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Vol. ${Formatters.numero(calc.volume, 3)} m³ · '
            'Peso ${Formatters.numero(calc.peso, 0)} kg · '
            'Aço ${Formatters.numero(calc.aco, 1)} kg',
            style: const TextStyle(
                fontSize: 11.5, color: AppColors.mutedForeground),
          ),
        ],
      ),
    );
  }
}

class _Totais extends StatelessWidget {
  const _Totais({required this.label, required this.valor, required this.cor});

  final String label;
  final int valor;
  final Color cor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 10.5, color: AppColors.mutedForeground)),
          const SizedBox(height: 2),
          Text('$valor',
              style: TextStyle(
                  fontSize: 20, fontWeight: FontWeight.w700, color: cor)),
        ],
      ),
    );
  }
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
        Text(texto, style: const TextStyle(fontSize: 11.5)),
      ],
    );
  }
}
