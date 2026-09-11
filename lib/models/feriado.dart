/// Feriado (tabela `feriados`).
class Feriado {
  const Feriado({
    required this.id,
    required this.nome,
    required this.data,
    this.tipo = 'nacional_pontual',
    this.recorrente = false,
    this.municipio,
    this.observacoes,
    this.ativo = true,
  });

  final String id;
  final String nome;

  /// Data no formato `yyyy-MM-dd` (para recorrentes, o ano é simbólico).
  final String data;
  final String tipo;
  final bool recorrente;
  final String? municipio;
  final String? observacoes;
  final bool ativo;

  String get tipoLabel => switch (tipo) {
        'nacional_fixo' => 'Nacional (fixo)',
        'municipal' => 'Municipal',
        _ => 'Nacional (pontual)',
      };

  factory Feriado.fromMap(Map<String, dynamic> m) => Feriado(
        id: m['id'] as String,
        nome: (m['nome'] as String?) ?? '',
        data: (m['data'] as String?) ?? '',
        tipo: (m['tipo'] as String?) ?? 'nacional_pontual',
        recorrente: (m['recorrente'] as bool?) ?? false,
        municipio: m['municipio'] as String?,
        observacoes: m['observacoes'] as String?,
        ativo: (m['ativo'] as bool?) ?? true,
      );
}
