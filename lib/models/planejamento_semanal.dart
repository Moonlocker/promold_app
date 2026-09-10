import '../core/utils/parse.dart';

/// Item de planejamento semanal (tabela `planejamento_semanal`).
///
/// Usado nos indicadores para comparar o produzido com o planejado por dia.
class PlanejamentoSemanal {
  const PlanejamentoSemanal({
    required this.id,
    required this.dataInicio,
    required this.dataFim,
    this.obraId,
    this.pecaCatalogoId,
    this.obraPecaId,
    this.tipo = 'producao',
  });

  final String id;

  /// Datas no formato `yyyy-MM-dd`.
  final String dataInicio;
  final String dataFim;
  final String? obraId;
  final String? pecaCatalogoId;
  final String? obraPecaId;

  /// `producao` ou `armacao`.
  final String tipo;

  factory PlanejamentoSemanal.fromMap(Map<String, dynamic> map) {
    return PlanejamentoSemanal(
      id: map['id'] as String,
      dataInicio: Parse.strOr(map['data_inicio']),
      dataFim: Parse.strOr(map['data_fim']),
      obraId: map['obra_id'] as String?,
      pecaCatalogoId: map['peca_catalogo_id'] as String?,
      obraPecaId: map['obra_peca_id'] as String?,
      tipo: Parse.strOr(map['tipo'], 'producao'),
    );
  }
}
