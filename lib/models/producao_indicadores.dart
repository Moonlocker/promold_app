import 'obra_peca.dart';

/// Produção consolidada de um dia (realizado x planejado).
class ProducaoDia {
  const ProducaoDia({
    required this.date,
    required this.label,
    required this.pecas,
    required this.planejado,
    required this.concreto,
    required this.aco,
    required this.concretoPlan,
    required this.acoPlan,
  });

  /// `yyyy-MM-dd`.
  final String date;

  /// `dd/MM` para exibição no eixo do gráfico.
  final String label;
  final int pecas;
  final int planejado;
  final double concreto;
  final double aco;
  final double concretoPlan;
  final double acoPlan;
}

/// Linha da matriz "Progresso por Obra": contagem exata por status.
class ObraProgresso {
  const ObraProgresso({
    required this.obraId,
    required this.nome,
    required this.total,
    required this.counts,
    this.cor,
  });

  final String obraId;
  final String nome;
  final String? cor;
  final int total;

  /// Status normalizado -> quantidade.
  final Map<String, int> counts;
}

/// Conjunto de indicadores calculados para o período/filtros selecionados.
class ProducaoIndicadores {
  const ProducaoIndicadores({
    required this.registros,
    required this.chartDiario,
    required this.obrasProgresso,
    required this.porTipo,
    required this.totalPeriodo,
    required this.diasComProducao,
    required this.mediaDiaria,
    required this.volumeConcreto,
    required this.acoTotal,
  });

  final List<ObraPeca> registros;
  final List<ProducaoDia> chartDiario;
  final List<ObraProgresso> obrasProgresso;
  final List<MapEntry<String, int>> porTipo;
  final int totalPeriodo;
  final int diasComProducao;
  final int mediaDiaria;
  final double volumeConcreto;
  final double acoTotal;

  static const empty = ProducaoIndicadores(
    registros: <ObraPeca>[],
    chartDiario: <ProducaoDia>[],
    obrasProgresso: <ObraProgresso>[],
    porTipo: <MapEntry<String, int>>[],
    totalPeriodo: 0,
    diasComProducao: 0,
    mediaDiaria: 0,
    volumeConcreto: 0,
    acoTotal: 0,
  );
}
