import '../core/utils/parse.dart';

/// Foto de obra (tabela `obras_fotos`).
class ObraFoto {
  const ObraFoto({
    required this.id,
    required this.obraId,
    required this.url,
    this.descricao,
    this.tipo = 'progresso',
    this.createdAt,
  });

  final String id;
  final String obraId;
  final String url;
  final String? descricao;
  final String tipo;
  final DateTime? createdAt;

  factory ObraFoto.fromMap(Map<String, dynamic> map) {
    return ObraFoto(
      id: map['id'] as String,
      obraId: (map['obra_id'] as String?) ?? '',
      url: (map['url'] as String?) ?? '',
      descricao: map['descricao'] as String?,
      tipo: (map['tipo'] as String?) ?? 'progresso',
      createdAt: Parse.date(map['created_at']),
    );
  }
}

/// Anexo de obra (tabela `obras_anexos`).
class ObraAnexo {
  const ObraAnexo({
    required this.id,
    required this.obraId,
    required this.nome,
    required this.url,
    this.tipo = 'documento',
    this.tamanho,
    this.createdAt,
  });

  final String id;
  final String obraId;
  final String nome;
  final String url;
  final String tipo;
  final int? tamanho;
  final DateTime? createdAt;

  factory ObraAnexo.fromMap(Map<String, dynamic> map) {
    return ObraAnexo(
      id: map['id'] as String,
      obraId: (map['obra_id'] as String?) ?? '',
      nome: (map['nome'] as String?) ?? 'Anexo',
      url: (map['url'] as String?) ?? '',
      tipo: (map['tipo'] as String?) ?? 'documento',
      tamanho: map['tamanho'] as int?,
      createdAt: Parse.date(map['created_at']),
    );
  }
}
