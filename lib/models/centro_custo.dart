/// Centro de custo (tabela `centros_custo`).
class CentroCusto {
  const CentroCusto({
    required this.id,
    required this.nome,
    this.descricao,
    this.ativo = true,
  });

  final String id;
  final String nome;
  final String? descricao;
  final bool ativo;

  factory CentroCusto.fromMap(Map<String, dynamic> map) {
    return CentroCusto(
      id: map['id'] as String,
      nome: (map['nome'] as String?) ?? 'Centro',
      descricao: map['descricao'] as String?,
      ativo: (map['ativo'] as bool?) ?? true,
    );
  }
}
