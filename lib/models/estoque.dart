import '../core/utils/parse.dart';

/// Local de estoque (tabela `estoques`).
///
/// A imagem de referência é embutida na `descricao` no formato
/// `[IMG:<url>] <texto>`, igual ao webapp.
class Estoque {
  const Estoque({
    required this.id,
    required this.nome,
    this.descricao,
    this.ativo = true,
    this.capacidade,
    this.categoriasPermitidas,
    this.pecasPermitidas,
    this.createdAt,
  });

  final String id;
  final String nome;
  final String? descricao;
  final bool ativo;
  final int? capacidade;
  final List<String>? categoriasPermitidas;
  final List<String>? pecasPermitidas;
  final DateTime? createdAt;

  static const nomeSistema = '__mapa_visual_sistema__';

  bool get isSistema => nome == nomeSistema;

  /// URL da imagem extraída de `[IMG:<url>]`.
  String? get imagemUrl {
    final d = descricao ?? '';
    final match = RegExp(r'\[IMG:([^\]]+)\]').firstMatch(d);
    return match?.group(1);
  }

  /// Descrição sem o marcador de imagem.
  String get descricaoLimpa {
    final d = descricao ?? '';
    return d.replaceAll(RegExp(r'\[IMG:[^\]]*\]'), '').trim();
  }

  bool get permiteTodas =>
      (categoriasPermitidas == null || categoriasPermitidas!.isEmpty) &&
      (pecasPermitidas == null || pecasPermitidas!.isEmpty);

  factory Estoque.fromMap(Map<String, dynamic> map) {
    List<String>? list(dynamic v) {
      if (v == null) return null;
      return (v as List).map((e) => e.toString()).toList();
    }

    return Estoque(
      id: map['id'] as String,
      nome: (map['nome'] as String?) ?? 'Estoque',
      descricao: map['descricao'] as String?,
      ativo: (map['ativo'] as bool?) ?? true,
      capacidade: Parse.numOrNull(map['capacidade'])?.toInt(),
      categoriasPermitidas: list(map['categorias_permitidas']),
      pecasPermitidas: list(map['pecas_permitidas']),
      createdAt: Parse.date(map['created_at']),
    );
  }
}

/// Compartimento de um estoque (tabela `compartimentos`).
class Compartimento {
  const Compartimento({
    required this.id,
    required this.nome,
    this.estoqueId,
    this.descricao,
    this.ocupado = false,
  });

  final String id;
  final String nome;
  final String? estoqueId;
  final String? descricao;
  final bool ocupado;

  factory Compartimento.fromMap(Map<String, dynamic> map) => Compartimento(
        id: map['id'] as String,
        nome: (map['nome'] as String?) ?? 'Compartimento',
        estoqueId: map['estoque_id'] as String?,
        descricao: map['descricao'] as String?,
        ocupado: (map['ocupado'] as bool?) ?? false,
      );
}

/// Configuração do canvas do mapa (tabela `estoque_visual_config`).
class EstoqueVisualConfig {
  const EstoqueVisualConfig({
    required this.estoqueId,
    this.canvasWidth = 1200,
    this.canvasHeight = 800,
    this.backgroundUrl,
    this.backgroundOpacity = 0.3,
  });

  final String estoqueId;
  final double canvasWidth;
  final double canvasHeight;
  final String? backgroundUrl;
  final double backgroundOpacity;

  factory EstoqueVisualConfig.fromMap(Map<String, dynamic> map) {
    return EstoqueVisualConfig(
      estoqueId: (map['estoque_id'] as String?) ?? '',
      canvasWidth: Parse.dbl(map['canvas_width'], 1200),
      canvasHeight: Parse.dbl(map['canvas_height'], 800),
      backgroundUrl: map['background_url'] as String?,
      backgroundOpacity: Parse.dbl(map['background_opacity'], 0.3),
    );
  }
}

/// Elemento do mapa (tabela `estoque_visual_elementos`).
class EstoqueVisualElemento {
  const EstoqueVisualElemento({
    required this.id,
    required this.estoqueId,
    this.tipo = 'compartimento',
    this.label,
    this.x = 0,
    this.y = 0,
    this.largura = 80,
    this.altura = 40,
    this.rotacao = 0,
    this.compartimentoId,
    this.linkedEstoqueId,
  });

  final String id;
  final String estoqueId;
  final String tipo; // 'compartimento' | 'label'
  final String? label;
  final double x;
  final double y;
  final double largura;
  final double altura;
  final double rotacao;
  final String? compartimentoId;

  /// Derivado de `compartimento_id → compartimentos.estoque_id`.
  final String? linkedEstoqueId;

  bool get isLabel => tipo == 'label';

  EstoqueVisualElemento copyWith({
    String? id,
    String? tipo,
    String? label,
    double? x,
    double? y,
    double? largura,
    double? altura,
    double? rotacao,
    String? compartimentoId,
    String? linkedEstoqueId,
  }) {
    return EstoqueVisualElemento(
      id: id ?? this.id,
      estoqueId: estoqueId,
      tipo: tipo ?? this.tipo,
      label: label ?? this.label,
      x: x ?? this.x,
      y: y ?? this.y,
      largura: largura ?? this.largura,
      altura: altura ?? this.altura,
      rotacao: rotacao ?? this.rotacao,
      compartimentoId: compartimentoId ?? this.compartimentoId,
      linkedEstoqueId: linkedEstoqueId ?? this.linkedEstoqueId,
    );
  }

  factory EstoqueVisualElemento.fromMap(Map<String, dynamic> map) {
    return EstoqueVisualElemento(
      id: map['id'] as String,
      estoqueId: (map['estoque_id'] as String?) ?? '',
      tipo: (map['tipo'] as String?) ?? 'compartimento',
      label: map['label'] as String?,
      x: Parse.dbl(map['x']),
      y: Parse.dbl(map['y']),
      largura: Parse.dbl(map['largura'], 80),
      altura: Parse.dbl(map['altura'], 40),
      rotacao: Parse.dbl(map['rotacao']),
      compartimentoId: map['compartimento_id'] as String?,
    );
  }
}

/// Peça atualmente em estoque, com dados de obra e catálogo já resolvidos.
class PecaEmEstoque {
  const PecaEmEstoque({
    required this.id,
    required this.obraId,
    this.obraNome = '',
    this.obraCor,
    this.pecaCatalogoId,
    this.pecaNome = 'Peça',
    this.categoriaId,
    this.identificador = '',
    this.comprimento,
    this.dataConcretagem,
    this.estoqueId,
    this.status = 'em_estoque',
  });

  final String id;
  final String obraId;
  final String obraNome;
  final String? obraCor;
  final String? pecaCatalogoId;
  final String pecaNome;
  final String? categoriaId;
  final String identificador;
  final num? comprimento;
  final DateTime? dataConcretagem;
  final String? estoqueId;
  final String status;

  factory PecaEmEstoque.fromMap(Map<String, dynamic> map) {
    final catalogo = map['pecas_catalogo'];
    final obra = map['obras'];
    return PecaEmEstoque(
      id: map['id'] as String,
      obraId: (map['obra_id'] as String?) ?? '',
      obraNome: obra is Map ? (obra['nome'] as String?) ?? '' : '',
      obraCor: obra is Map ? obra['cor'] as String? : null,
      pecaCatalogoId: map['peca_catalogo_id'] as String?,
      pecaNome:
          catalogo is Map ? (catalogo['nome'] as String?) ?? 'Peça' : 'Peça',
      categoriaId: catalogo is Map ? catalogo['categoria_id'] as String? : null,
      identificador: (map['identificador'] as String?) ?? '',
      comprimento: Parse.numOrNull(map['comprimento']),
      dataConcretagem: Parse.date(map['data_concretagem']),
      estoqueId: map['estoque_id'] as String?,
      status: (map['status'] as String?) ?? 'em_estoque',
    );
  }
}

