/// Cargo (tabela `cargos`).
class Cargo {
  const Cargo({
    required this.id,
    required this.nome,
    this.setorId,
    this.salario,
    this.descricao,
    this.ativo = true,
    this.setorNome,
  });

  final String id;
  final String nome;
  final String? setorId;
  final num? salario;
  final String? descricao;
  final bool ativo;
  final String? setorNome;

  factory Cargo.fromMap(Map<String, dynamic> map) {
    String? nomeRel(dynamic rel) {
      if (rel is Map && rel['nome'] is String) return rel['nome'] as String;
      return null;
    }

    return Cargo(
      id: map['id'] as String,
      nome: (map['nome'] as String?) ?? 'Cargo',
      setorId: map['setor_id'] as String?,
      salario: map['salario'] as num?,
      descricao: map['descricao'] as String?,
      ativo: (map['ativo'] as bool?) ?? true,
      setorNome: nomeRel(map['setores']),
    );
  }
}
