import '../models/obra.dart';

/// Métricas exibidas no dashboard, espelhando `src/pages/Dashboard.tsx`.
class DashboardMetrics {
  const DashboardMetrics({
    required this.obrasAtivas,
    required this.producaoHoje,
    required this.pecasPendentes,
    required this.concretoSemanaM3,
    required this.obrasPrioritarias,
  });

  final int obrasAtivas;
  final int producaoHoje;
  final int pecasPendentes;
  final double concretoSemanaM3;
  final List<Obra> obrasPrioritarias;

  static const empty = DashboardMetrics(
    obrasAtivas: 0,
    producaoHoje: 0,
    pecasPendentes: 0,
    concretoSemanaM3: 0,
    obrasPrioritarias: <Obra>[],
  );
}
