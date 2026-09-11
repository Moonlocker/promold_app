/// Veículo da frota (tabela `veiculos`).
class Veiculo {
  const Veiculo({
    required this.id,
    required this.modelo,
    required this.placa,
    this.tipo,
    this.capacidade,
    this.propriedade = 'propria',
    this.ativo = true,
    this.motoristaPadraoId,
    this.fotoUrl,
  });

  final String id;
  final String modelo;
  final String placa;
  final String? tipo;
  final num? capacidade;
  final String propriedade;
  final bool ativo;
  final String? motoristaPadraoId;
  final String? fotoUrl;

  factory Veiculo.fromMap(Map<String, dynamic> m) => Veiculo(
        id: m['id'] as String,
        modelo: (m['modelo'] as String?) ?? '',
        placa: (m['placa'] as String?) ?? '',
        tipo: m['tipo'] as String?,
        capacidade: m['capacidade'] as num?,
        propriedade: (m['propriedade'] as String?) ?? 'propria',
        ativo: (m['ativo'] as bool?) ?? true,
        motoristaPadraoId: m['motorista_padrao_id'] as String?,
        fotoUrl: m['foto_url'] as String?,
      );
}
