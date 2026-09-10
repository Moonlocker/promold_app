/// Categoria de peça (tabela `categorias_peca`).
class CategoriaPeca {
  const CategoriaPeca({
    required this.id,
    required this.nome,
    this.descricao,
    this.ativa = true,
  });

  final String id;
  final String nome;
  final String? descricao;
  final bool ativa;

  factory CategoriaPeca.fromMap(Map<String, dynamic> map) {
    return CategoriaPeca(
      id: map['id'] as String,
      nome: (map['nome'] as String?) ?? 'Categoria',
      descricao: map['descricao'] as String?,
      ativa: (map['ativa'] as bool?) ?? true,
    );
  }
}
