import '../core/utils/parse.dart';

/// Registro de histórico de obra (tabela `obras_historico`), podendo também
/// representar um log de planejamento sintético (`_source == 'planejamento'`).
class ObraHistorico {
  const ObraHistorico({
    required this.id,
    required this.obraId,
    required this.tipo,
    required this.descricao,
    this.detalhes,
    this.responsavel,
    this.createdAt,
    this.source = 'historico',
  });

  final String id;
  final String obraId;
  final String tipo;
  final String descricao;
  final String? detalhes;
  final String? responsavel;
  final DateTime? createdAt;

  /// 'historico' ou 'planejamento'.
  final String source;

  bool get isManual => tipo == 'manual' && source == 'historico';

  factory ObraHistorico.fromMap(Map<String, dynamic> map) {
    return ObraHistorico(
      id: map['id'] as String,
      obraId: (map['obra_id'] as String?) ?? '',
      tipo: (map['tipo'] as String?) ?? 'manual',
      descricao: (map['descricao'] as String?) ?? '',
      detalhes: map['detalhes'] as String?,
      responsavel: map['responsavel'] as String?,
      createdAt: Parse.date(map['created_at']),
    );
  }
}

/// Preferências de monitoramento por usuário (tabela `obra_monitoramento`).
class ObraMonitoramento {
  const ObraMonitoramento({
    this.id,
    required this.obraId,
    this.notifProducao = false,
    this.notifCarregamento = false,
    this.notifAguardando = false,
    this.notifMontagem = false,
    this.notifManual = false,
  });

  final String? id;
  final String obraId;
  final bool notifProducao;
  final bool notifCarregamento;
  final bool notifAguardando;
  final bool notifMontagem;
  final bool notifManual;

  factory ObraMonitoramento.fromMap(Map<String, dynamic> map) {
    return ObraMonitoramento(
      id: map['id'] as String?,
      obraId: (map['obra_id'] as String?) ?? '',
      notifProducao: Parse.boolean(map['notif_producao']),
      notifCarregamento: Parse.boolean(map['notif_carregamento']),
      notifAguardando: Parse.boolean(map['notif_aguardando']),
      notifMontagem: Parse.boolean(map['notif_montagem']),
      notifManual: Parse.boolean(map['notif_manual']),
    );
  }
}

/// Insumo de obra (tabela `obras_insumos`).
class ObraInsumo {
  const ObraInsumo({
    required this.id,
    required this.obraId,
    required this.descricao,
    this.codigo,
    this.quantidade = 1,
    this.unidade = 'un',
    this.origem = 'manual',
    this.valorUnitario,
    this.observacoes,
    this.ifcExpressId,
    this.createdAt,
  });

  final String id;
  final String obraId;
  final String descricao;
  final String? codigo;
  final num quantidade;
  final String unidade;
  final String origem;
  final num? valorUnitario;
  final String? observacoes;
  final String? ifcExpressId;
  final DateTime? createdAt;

  num get valorTotal => quantidade * (valorUnitario ?? 0);

  factory ObraInsumo.fromMap(Map<String, dynamic> map) {
    return ObraInsumo(
      id: map['id'] as String,
      obraId: (map['obra_id'] as String?) ?? '',
      descricao: (map['descricao'] as String?) ?? '',
      codigo: map['codigo'] as String?,
      quantidade: Parse.numOrNull(map['quantidade']) ?? 1,
      unidade: (map['unidade'] as String?) ?? 'un',
      origem: (map['origem'] as String?) ?? 'manual',
      valorUnitario: Parse.numOrNull(map['valor_unitario']),
      observacoes: map['observacoes'] as String?,
      ifcExpressId: map['ifc_express_id']?.toString(),
      createdAt: Parse.date(map['created_at']),
    );
  }
}
