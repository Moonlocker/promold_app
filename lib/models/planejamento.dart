/// Estruturas do módulo de Planejamento (armação/produção e montagem).
class PlanejamentoItem {
  const PlanejamentoItem({
    required this.planId,
    required this.obraId,
    required this.obraNome,
    required this.pecaNome,
    required this.identificador,
    required this.status,
    required this.concluido,
    this.obraCor,
    this.obraPecaId,
  });

  final String planId;
  final String obraId;
  final String obraNome;
  final String? obraCor;
  final String? obraPecaId;
  final String pecaNome;
  final String identificador;
  final String status;
  final bool concluido;
}

class PlanejamentoDia {
  const PlanejamentoDia({
    required this.dia,
    required this.diaStr,
    required this.diaNome,
    required this.total,
    required this.concluidos,
  });

  final DateTime dia;
  final String diaStr;
  final String diaNome;
  final int total;
  final int concluidos;

  int get percentual => total > 0 ? ((concluidos / total) * 100).round() : 0;
}

class PlanejamentoDados {
  const PlanejamentoDados({required this.dias, required this.itensDoDia});

  final List<PlanejamentoDia> dias;
  final List<PlanejamentoItem> itensDoDia;

  static const empty = PlanejamentoDados(
    dias: <PlanejamentoDia>[],
    itensDoDia: <PlanejamentoItem>[],
  );
}

/// Planejamento de montagem (tabela `planejamento_montagem`).
class PlanejamentoMontagem {
  const PlanejamentoMontagem({
    required this.id,
    required this.dataInicio,
    required this.dataFim,
    this.obraId,
    this.observacoes,
    this.ocorrencias,
  });

  final String id;
  final String dataInicio;
  final String dataFim;
  final String? obraId;
  final String? observacoes;
  final String? ocorrencias;

  factory PlanejamentoMontagem.fromMap(Map<String, dynamic> map) {
    return PlanejamentoMontagem(
      id: map['id'] as String,
      dataInicio: (map['data_inicio']?.toString()) ?? '',
      dataFim: (map['data_fim']?.toString()) ?? '',
      obraId: map['obra_id'] as String?,
      observacoes: map['observacoes'] as String?,
      ocorrencias: map['ocorrencias'] as String?,
    );
  }
}
