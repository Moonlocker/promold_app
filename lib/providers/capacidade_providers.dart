import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/utils/formatters.dart';
import '../models/capacidade.dart';
import 'supabase_providers.dart';

/// Áreas produtivas.
final areasProdutivasProvider = FutureProvider<List<AreaProdutiva>>(
  (ref) => ref.watch(capacidadeRepositoryProvider).listAreas(),
);

/// Capacidades cadastradas.
final capacidadesFabricaProvider = FutureProvider<List<CapacidadeFabrica>>(
  (ref) => ref.watch(capacidadeRepositoryProvider).listCapacidades(),
);

const List<String> _diasAbrev = [
  'dom',
  'seg',
  'ter',
  'qua',
  'qui',
  'sex',
  'sáb',
];

/// Capacidade x planejado por dia da semana iniciada em [inicio] (domingo).
final capacidadeSemanaProvider =
    FutureProvider.family<List<CapacidadeDia>, DateTime>((ref, inicio) async {
  final caps = await ref.watch(capacidadesFabricaProvider.future);
  final fim = inicio.add(const Duration(days: 6));
  final contagem = await ref
      .watch(producaoRepositoryProvider)
      .contagemPlanejamentoPorDia(
        Formatters.iso(inicio),
        Formatters.iso(fim),
      );

  final dias = <CapacidadeDia>[];
  for (var i = 0; i < 7; i++) {
    final d = inicio.add(Duration(days: i));
    final dow = d.weekday % 7;
    final capacidade = caps.where((c) => c.ativa).fold<double>(0, (a, c) {
      if (c.diaSemana == null || c.diaSemana == dow) {
        return a + c.capacidadeDiaria;
      }
      return a;
    });
    final diaStr = Formatters.iso(d);
    dias.add(
      CapacidadeDia(
        data: d,
        label: _diasAbrev[dow],
        capacidade: capacidade,
        planejado: contagem[diaStr] ?? 0,
      ),
    );
  }
  return dias;
});
