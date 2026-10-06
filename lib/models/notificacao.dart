/// Notificação in-app (tabela `notificacoes`), igual ao sino do sistema web.
class Notificacao {
  const Notificacao({
    required this.id,
    required this.tipo,
    required this.titulo,
    this.descricao,
    this.obraId,
    this.lida = false,
    this.createdAt,
  });

  final String id;
  final String tipo;
  final String titulo;
  final String? descricao;
  final String? obraId;
  final bool lida;
  final DateTime? createdAt;

  factory Notificacao.fromMap(Map<String, dynamic> map) {
    return Notificacao(
      id: map['id'] as String,
      tipo: (map['tipo'] as String?) ?? 'manual',
      titulo: (map['titulo'] as String?) ?? '',
      descricao: map['descricao'] as String?,
      obraId: map['obra_id'] as String?,
      lida: (map['lida'] as bool?) ?? false,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'] as String)
          : null,
    );
  }
}
