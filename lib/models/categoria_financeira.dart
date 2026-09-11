/// Categoria financeira (tabela `categorias_financeiras`).
class CategoriaFinanceira {
  const CategoriaFinanceira({
    required this.id,
    required this.nome,
    this.tipo = 'ambos',
    this.ativa = true,
  });

  final String id;
  final String nome;
  final String tipo;
  final bool ativa;

  String get tipoLabel => switch (tipo) {
        'receita' => 'Receita',
        'despesa' => 'Despesa',
        _ => 'Ambos',
      };

  factory CategoriaFinanceira.fromMap(Map<String, dynamic> map) {
    return CategoriaFinanceira(
      id: map['id'] as String,
      nome: (map['nome'] as String?) ?? 'Categoria',
      tipo: (map['tipo'] as String?) ?? 'ambos',
      ativa: (map['ativa'] as bool?) ?? true,
    );
  }
}
