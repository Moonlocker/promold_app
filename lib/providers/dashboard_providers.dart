import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/logic/painel_calc.dart';
import '../core/utils/formatters.dart';
import '../models/dashboard_semana.dart';
import '../models/obra_historico.dart';
import 'obra_providers.dart';
import 'supabase_providers.dart';

const List<String> _diasAbrev = [
  'dom',
  'seg',
  'ter',
  'qua',
  'qui',
  'sex',
  'sáb',
];

bool _noDia(DateTime d, DateTime dia) =>
    d.year == dia.year && d.month == dia.month && d.day == dia.day;

/// Produção semanal (realizado x planejado) para o gráfico do Dashboard.
/// [offset] em semanas: 0 = semana atual, -1 = anterior, etc.
final dashboardSemanaProvider =
    FutureProvider.family<DashboardSemana, int>((ref, offset) async {
  final pecas = await ref.watch(todasPecasResumoProvider.future);
  final inicio = inicioDaSemana(DateTime.now())
      .add(Duration(days: offset * 7));
  final fim = inicio.add(const Duration(days: 6));
  final inicioAnterior = inicio.subtract(const Duration(days: 7));

  final planPorDia = await ref
      .watch(producaoRepositoryProvider)
      .contagemPlanejamentoPorDia(
        Formatters.iso(inicio),
        Formatters.iso(fim),
      );

  final produzidas = pecas
      .where((p) => p.dataConcretagem != null && p.status != 'pendente')
      .toList();

  int contar(DateTime dia) =>
      produzidas.where((p) => _noDia(p.dataConcretagem!, dia)).length;

  final dias = <DashboardSemanaDia>[];
  for (var i = 0; i < 7; i++) {
    final dia = inicio.add(Duration(days: i));
    final diaAnterior = inicioAnterior.add(Duration(days: i));
    dias.add(
      DashboardSemanaDia(
        data: dia,
        diaSemana: _diasAbrev[dia.weekday % 7],
        label: '${dia.day.toString().padLeft(2, '0')}/'
            '${dia.month.toString().padLeft(2, '0')}',
        produzidoAtual: contar(dia),
        produzidoAnterior: contar(diaAnterior),
        planejado: planPorDia[Formatters.iso(dia)] ?? 0,
      ),
    );
  }

  return DashboardSemana(inicio: inicio, fim: fim, dias: dias);
});

/// Atividades recentes (últimas 24h) de todas as obras.
final dashboardRecentActivityProvider =
    FutureProvider<List<ObraHistorico>>((ref) {
  return ref
      .watch(obraHistoricoRepositoryProvider)
      .listRecentActivity(horas: 24, limit: 60);
});
