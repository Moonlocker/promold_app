/// Modelos de Capacidade da Fábrica.
library;

class AreaProdutiva {
  const AreaProdutiva({
    required this.id,
    required this.nome,
    this.descricao,
    this.ativa = true,
  });

  final String id;
  final String nome;
  final String? descricao;
  final bool ativa;

  factory AreaProdutiva.fromMap(Map<String, dynamic> m) => AreaProdutiva(
        id: m['id'] as String,
        nome: (m['nome'] as String?) ?? 'Área',
        descricao: m['descricao'] as String?,
        ativa: (m['ativa'] as bool?) ?? true,
      );
}

class CapacidadeFabrica {
  const CapacidadeFabrica({
    required this.id,
    this.areaId,
    this.capacidadeDiaria = 0,
    this.capacidadeSemanal,
    this.ativa = true,
  });

  final String id;
  final String? areaId;
  final double capacidadeDiaria;
  final double? capacidadeSemanal;
  final bool ativa;

  static double _d(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }

  static double? _dn(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  factory CapacidadeFabrica.fromMap(Map<String, dynamic> m) =>
      CapacidadeFabrica(
        id: m['id'] as String,
        areaId: m['area_produtiva_id'] as String?,
        capacidadeDiaria: _d(m['capacidade_diaria']),
        capacidadeSemanal: _dn(m['capacidade_semanal']),
        ativa: (m['ativa'] as bool?) ?? true,
      );
}
