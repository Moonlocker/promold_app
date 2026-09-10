import '../core/utils/parse.dart';

/// Processo/etapa manual (tabela `processos_etapas`).
class ProcessoEtapa {
  const ProcessoEtapa({
    required this.id,
    required this.nome,
    this.cor = '#94a3b8',
    this.ordem = 0,
  });

  final String id;
  final String nome;
  final String cor;
  final int ordem;

  factory ProcessoEtapa.fromMap(Map<String, dynamic> map) {
    return ProcessoEtapa(
      id: map['id'] as String,
      nome: (map['nome'] as String?) ?? 'Processo',
      cor: (map['cor'] as String?) ?? '#94a3b8',
      ordem: Parse.intOr(map['ordem']),
    );
  }
}

/// Item de um processo (tabela `processos_etapas_itens`).
class ProcessoEtapaItem {
  const ProcessoEtapaItem({
    required this.id,
    required this.processoId,
    required this.nome,
    this.ordem = 0,
  });

  final String id;
  final String processoId;
  final String nome;
  final int ordem;

  factory ProcessoEtapaItem.fromMap(Map<String, dynamic> map) {
    return ProcessoEtapaItem(
      id: map['id'] as String,
      processoId: (map['processo_id'] as String?) ?? '',
      nome: (map['nome'] as String?) ?? 'Etapa',
      ordem: Parse.intOr(map['ordem']),
    );
  }
}

/// Status de uma etapa manual em uma obra (tabela `obra_etapa_status`).
class ObraEtapaStatus {
  const ObraEtapaStatus({
    required this.id,
    required this.obraId,
    required this.etapaItemId,
    this.status = 'pendente',
  });

  final String id;
  final String obraId;
  final String etapaItemId;
  final String status;

  factory ObraEtapaStatus.fromMap(Map<String, dynamic> map) {
    return ObraEtapaStatus(
      id: map['id'] as String,
      obraId: (map['obra_id'] as String?) ?? '',
      etapaItemId: (map['etapa_item_id'] as String?) ?? '',
      status: (map['status'] as String?) ?? 'pendente',
    );
  }
}
