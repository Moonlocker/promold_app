/// Setor da empresa (tabela `setores`).
class Setor {
  const Setor({
    required this.id,
    required this.nome,
    this.descricao,
    this.ativo = true,
  });

  final String id;
  final String nome;
  final String? descricao;
  final bool ativo;

  factory Setor.fromMap(Map<String, dynamic> map) {
    return Setor(
      id: map['id'] as String,
      nome: (map['nome'] as String?) ?? 'Setor',
      descricao: map['descricao'] as String?,
      ativo: (map['ativo'] as bool?) ?? true,
    );
  }
}
