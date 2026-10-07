/// Dados do gráfico "Produção Semanal" do Dashboard.
library;

class DashboardSemanaDia {
  const DashboardSemanaDia({
    required this.data,
    required this.diaSemana,
    required this.label,
    required this.produzidoAtual,
    required this.produzidoAnterior,
    required this.planejado,
  });

  final DateTime data;

  /// Abreviação do dia da semana (ex.: `seg`).
  final String diaSemana;

  /// Data no formato `dd/MM`.
  final String label;
  final int produzidoAtual;
  final int produzidoAnterior;
  final int planejado;
}

class DashboardSemana {
  const DashboardSemana({
    required this.inicio,
    required this.fim,
    required this.dias,
  });

  final DateTime inicio;
  final DateTime fim;
  final List<DashboardSemanaDia> dias;

  int get totalAtual =>
      dias.fold(0, (a, d) => a + d.produzidoAtual);
  int get totalAnterior =>
      dias.fold(0, (a, d) => a + d.produzidoAnterior);
  int get totalPlanejado =>
      dias.fold(0, (a, d) => a + d.planejado);
}
