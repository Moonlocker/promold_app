/// Módulo comercial do SaaS (tabela `modulos`).
class ModuloComercial {
  const ModuloComercial({
    required this.id,
    required this.slug,
    required this.nome,
    this.descricao,
    this.cor,
    this.valorMensal = 0,
    this.precoPorM3 = 0,
    this.core = false,
  });

  final String id;
  final String slug;
  final String nome;
  final String? descricao;
  final String? cor;
  final double valorMensal;
  final double precoPorM3;
  final bool core;

  static double _d(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }

  factory ModuloComercial.fromMap(Map<String, dynamic> m) => ModuloComercial(
        id: m['id'] as String,
        slug: (m['slug'] as String?) ?? '',
        nome: (m['nome'] as String?) ?? 'Módulo',
        descricao: m['descricao'] as String?,
        cor: m['cor'] as String?,
        valorMensal: _d(m['valor_mensal']),
        precoPorM3: _d(m['preco_por_m3']),
        core: (m['core'] as bool?) ?? false,
      );
}
