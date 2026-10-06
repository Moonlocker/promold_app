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

  Map<String, dynamic> toMap() => {
        'obrasAtivas': obrasAtivas,
        'producaoHoje': producaoHoje,
        'pecasPendentes': pecasPendentes,
        'concretoSemanaM3': concretoSemanaM3,
        'obrasPrioritarias':
            obrasPrioritarias.map((o) => o.toMap()).toList(),
      };

  factory DashboardMetrics.fromMap(Map<String, dynamic> map) {
    return DashboardMetrics(
      obrasAtivas: (map['obrasAtivas'] as num?)?.toInt() ?? 0,
      producaoHoje: (map['producaoHoje'] as num?)?.toInt() ?? 0,
      pecasPendentes: (map['pecasPendentes'] as num?)?.toInt() ?? 0,
      concretoSemanaM3: (map['concretoSemanaM3'] as num?)?.toDouble() ?? 0,
      obrasPrioritarias: ((map['obrasPrioritarias'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => Obra.fromMap(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }
}
