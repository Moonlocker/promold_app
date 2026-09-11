/// Arquivo IFC anexado a uma obra (tabela `obras_ifc_arquivos`).
class ObraIfcArquivo {
  const ObraIfcArquivo({
    required this.id,
    required this.obraId,
    required this.nome,
    required this.url,
    this.storagePath,
    this.tamanhoBytes,
    this.observacoes,
    this.ativo = true,
    this.viewerState = const {},
    this.createdAt,
  });

  final String id;
  final String obraId;
  final String nome;
  final String url;
  final String? storagePath;
  final int? tamanhoBytes;
  final String? observacoes;
  final bool ativo;
  final Map<String, dynamic> viewerState;
  final DateTime? createdAt;

  factory ObraIfcArquivo.fromMap(Map<String, dynamic> m) => ObraIfcArquivo(
        id: m['id'] as String,
        obraId: (m['obra_id'] as String?) ?? '',
        nome: (m['nome'] as String?) ?? 'Modelo.ifc',
        url: (m['url'] as String?) ?? '',
        storagePath: m['storage_path'] as String?,
        tamanhoBytes: (m['tamanho_bytes'] as num?)?.toInt(),
        observacoes: m['observacoes'] as String?,
        ativo: (m['ativo'] as bool?) ?? true,
        viewerState: m['viewer_state'] is Map
            ? Map<String, dynamic>.from(m['viewer_state'] as Map)
            : const {},
        createdAt: m['created_at'] != null
            ? DateTime.tryParse(m['created_at'] as String)
            : null,
      );
}
