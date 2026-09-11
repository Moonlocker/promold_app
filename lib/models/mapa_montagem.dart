/// Modelos do Mapa de Montagem (tabelas `mapa_montagem_vistas` e
/// `mapa_montagem_celulas`).
class MapaMontagemVista {
  const MapaMontagemVista({
    required this.id,
    required this.nome,
    this.descricao,
    this.linhas = 6,
    this.colunas = 6,
    this.tipo = 'grade',
    this.imagemUrl,
    this.ordem = 0,
  });

  final String id;
  final String nome;
  final String? descricao;
  final int linhas;
  final int colunas;
  final String tipo;
  final String? imagemUrl;
  final int ordem;

  factory MapaMontagemVista.fromMap(Map<String, dynamic> m) =>
      MapaMontagemVista(
        id: m['id'] as String,
        nome: (m['nome'] as String?) ?? 'Vista',
        descricao: m['descricao'] as String?,
        linhas: (m['linhas'] as num?)?.toInt() ?? 6,
        colunas: (m['colunas'] as num?)?.toInt() ?? 6,
        tipo: (m['tipo'] as String?) ?? 'grade',
        imagemUrl: m['imagem_url'] as String?,
        ordem: (m['ordem'] as num?)?.toInt() ?? 0,
      );
}

class MapaMontagemCelula {
  const MapaMontagemCelula({
    required this.linha,
    required this.coluna,
    this.obraPecaId,
    this.pecaCatalogoId,
    this.identificador,
    this.status,
  });

  final int linha;
  final int coluna;
  final String? obraPecaId;
  final String? pecaCatalogoId;
  final String? identificador;
  final String? status;

  bool get vazia => obraPecaId == null;

  factory MapaMontagemCelula.fromMap(Map<String, dynamic> m) =>
      MapaMontagemCelula(
        linha: (m['linha'] as num?)?.toInt() ?? 0,
        coluna: (m['coluna'] as num?)?.toInt() ?? 0,
        obraPecaId: m['obra_peca_id'] as String?,
        pecaCatalogoId: m['peca_catalogo_id'] as String?,
        identificador: m['identificador'] as String?,
        status: m['status'] as String?,
      );
}
