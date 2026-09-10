/// Obra/projeto (tabela `obras`).
class Obra {
  const Obra({
    required this.id,
    required this.nome,
    required this.cliente,
    this.endereco,
    this.status = 'planejamento',
    this.dataInicio,
    this.dataPrevisao,
    this.dataConclusao,
    this.prioridade = 1,
    this.observacoes,
    this.fotoUrl,
    this.cor,
    this.valorObra,
    this.contatoResponsavel,
    this.telefoneContato,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String nome;
  final String cliente;
  final String? endereco;
  final String status;
  final DateTime? dataInicio;
  final DateTime? dataPrevisao;
  final DateTime? dataConclusao;
  final int prioridade;
  final String? observacoes;
  final String? fotoUrl;
  final String? cor;
  final num? valorObra;
  final String? contatoResponsavel;
  final String? telefoneContato;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get ativa => status == 'ativa';

  factory Obra.fromMap(Map<String, dynamic> map) {
    return Obra(
      id: map['id'] as String,
      nome: (map['nome'] as String?) ?? 'Obra',
      cliente: (map['cliente'] as String?) ?? '',
      endereco: map['endereco'] as String?,
      status: (map['status'] as String?) ?? 'planejamento',
      dataInicio: _parseDate(map['data_inicio']),
      dataPrevisao: _parseDate(map['data_previsao']),
      dataConclusao: _parseDate(map['data_conclusao']),
      prioridade: (map['prioridade'] as int?) ?? 1,
      observacoes: map['observacoes'] as String?,
      fotoUrl: map['foto_url'] as String?,
      cor: map['cor'] as String?,
      valorObra: map['valor_obra'] as num?,
      contatoResponsavel: map['contato_responsavel'] as String?,
      telefoneContato: map['telefone_contato'] as String?,
      createdAt: _parseDate(map['created_at']),
      updatedAt: _parseDate(map['updated_at']),
    );
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value as String);
  }
}
