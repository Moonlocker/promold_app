/// Ausência de funcionário (tabela `ausencias`).
class Ausencia {
  const Ausencia({
    required this.id,
    required this.tipo,
    required this.dataInicio,
    required this.dataFim,
    this.funcionarioId,
    this.motivo,
    this.funcionarioNome,
  });

  final String id;
  final String tipo;
  final String dataInicio;
  final String dataFim;
  final String? funcionarioId;
  final String? motivo;
  final String? funcionarioNome;

  String get tipoLabel => switch (tipo) {
        'falta' => 'Falta',
        'atestado' => 'Atestado',
        'ferias' => 'Férias',
        'licenca' => 'Licença',
        _ => 'Outro',
      };

  factory Ausencia.fromMap(Map<String, dynamic> map) {
    String? nomeRel(dynamic rel) {
      if (rel is Map && rel['nome'] is String) return rel['nome'] as String;
      return null;
    }

    return Ausencia(
      id: map['id'] as String,
      tipo: (map['tipo'] as String?) ?? 'outro',
      dataInicio: (map['data_inicio'] as String?) ?? '',
      dataFim: (map['data_fim'] as String?) ?? '',
      funcionarioId: map['funcionario_id'] as String?,
      motivo: map['motivo'] as String?,
      funcionarioNome: nomeRel(map['funcionarios']),
    );
  }
}
