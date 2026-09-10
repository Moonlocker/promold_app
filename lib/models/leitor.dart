import '../core/utils/parse.dart';

/// Peça resumida usada nos leitores de registro (armada/concretada/estoque/montagem).
class PecaLeitor {
  const PecaLeitor({
    required this.id,
    required this.identificador,
    required this.status,
    this.pecaNome = '',
    this.obraNome = '',
    this.dataReferencia,
  });

  final String id;
  final String identificador;
  final String status;
  final String pecaNome;
  final String obraNome;
  final DateTime? dataReferencia;

  factory PecaLeitor.fromMap(Map<String, dynamic> map, String campoData) {
    final catalogo = map['pecas_catalogo'];
    final obra = map['obras'];
    return PecaLeitor(
      id: map['id'] as String,
      identificador: (map['identificador'] as String?) ?? '',
      status: (map['status'] as String?) ?? 'pendente',
      pecaNome: catalogo is Map
          ? (catalogo['nome'] as String?) ?? ''
          : '',
      obraNome: obra is Map ? (obra['nome'] as String?) ?? '' : '',
      dataReferencia: Parse.date(map[campoData]),
    );
  }
}

/// Lote de concreto vinculado a uma peça (tabela `qc_lotes_concreto`).
class LoteConcreto {
  const LoteConcreto({
    required this.id,
    this.codigo,
    this.fckMpa,
    this.dataConcretagem,
    this.fornecedor,
    this.volumeM3,
    this.slump,
  });

  final String id;
  final String? codigo;
  final num? fckMpa;
  final DateTime? dataConcretagem;
  final String? fornecedor;
  final num? volumeM3;
  final String? slump;

  factory LoteConcreto.fromMap(Map<String, dynamic> map) {
    return LoteConcreto(
      id: map['id'] as String,
      codigo: map['codigo'] as String?,
      fckMpa: Parse.numOrNull(map['fck_mpa']),
      dataConcretagem: Parse.date(map['data_concretagem']),
      fornecedor: map['fornecedor'] as String?,
      volumeM3: Parse.numOrNull(map['volume_m3']),
      slump: map['slump']?.toString(),
    );
  }
}

/// Peça completa para a tela de consulta (com obra, catálogo, posição e lote).
class PecaConsulta {
  const PecaConsulta({
    required this.id,
    required this.obraId,
    required this.identificador,
    required this.status,
    this.obraNome = '',
    this.obraCor,
    this.catalogoNome = '',
    this.categoriaNome,
    this.tipoCalculo = 'linear',
    this.posicao,
    this.lote,
    this.observacoes,
    this.pdfUrl,
    this.largura,
    this.altura,
    this.comprimento,
    this.diametro,
    this.volumeConcreto,
    this.volumeConcretoPorMetro,
    this.kgAcoPorMetro,
    this.dataArmacao,
    this.dataConcretagem,
    this.dataEstoque,
    this.dataCarregamento,
    this.dataMontagem,
  });

  final String id;
  final String obraId;
  final String identificador;
  final String status;
  final String obraNome;
  final String? obraCor;
  final String catalogoNome;
  final String? categoriaNome;
  final String tipoCalculo;
  final String? posicao;
  final LoteConcreto? lote;
  final String? observacoes;
  final String? pdfUrl;
  final num? largura;
  final num? altura;
  final num? comprimento;
  final num? diametro;
  final num? volumeConcreto;
  final num? volumeConcretoPorMetro;
  final num? kgAcoPorMetro;
  final DateTime? dataArmacao;
  final DateTime? dataConcretagem;
  final DateTime? dataEstoque;
  final DateTime? dataCarregamento;
  final DateTime? dataMontagem;

  factory PecaConsulta.fromMap(Map<String, dynamic> map) {
    final obra = map['obra'];
    final catalogo = map['catalogo'];
    final posicaoList = map['posicao'];
    final lote = map['lote'];

    String? posicao;
    if (posicaoList is List && posicaoList.isNotEmpty) {
      final cell = Map<String, dynamic>.from(posicaoList.first as Map);
      final vista = cell['vista'];
      final descricao =
          vista is Map ? (vista['descricao'] as String?) ?? '' : '';
      final match = RegExp(r'^\{FOOTER:([^}]*)\}').firstMatch(descricao);
      final footer = match != null ? match.group(1) ?? 'V' : 'V';
      final coluna = (cell['coluna'] as num?)?.toInt() ?? 0;
      final linha = (cell['linha'] as num?)?.toInt() ?? 0;
      posicao = '$footer${coluna + 1}-${linha + 1}';
    }

    String? categoriaNome;
    if (catalogo is Map) {
      final cat = catalogo['categoria'];
      if (cat is Map) categoriaNome = cat['nome'] as String?;
    }

    return PecaConsulta(
      id: map['id'] as String,
      obraId: obra is Map ? (obra['id'] as String?) ?? '' : '',
      identificador: (map['identificador'] as String?) ?? '',
      status: (map['status'] as String?) ?? 'pendente',
      obraNome: obra is Map ? (obra['nome'] as String?) ?? '' : '',
      obraCor: obra is Map ? obra['cor'] as String? : null,
      catalogoNome:
          catalogo is Map ? (catalogo['nome'] as String?) ?? '' : '',
      categoriaNome: categoriaNome,
      tipoCalculo:
          catalogo is Map ? (catalogo['tipo_calculo'] as String?) ?? 'linear' : 'linear',
      posicao: posicao,
      lote: lote is Map
          ? LoteConcreto.fromMap(Map<String, dynamic>.from(lote))
          : null,
      observacoes: map['observacoes'] as String?,
      pdfUrl: map['pdf_url'] as String?,
      largura: Parse.numOrNull(map['largura']),
      altura: Parse.numOrNull(map['altura']),
      comprimento: Parse.numOrNull(map['comprimento']),
      diametro: Parse.numOrNull(map['diametro']),
      volumeConcreto: Parse.numOrNull(map['volume_concreto']),
      volumeConcretoPorMetro: Parse.numOrNull(map['volume_concreto_por_metro']),
      kgAcoPorMetro: Parse.numOrNull(map['kg_aco_por_metro']),
      dataArmacao: Parse.date(map['data_armacao']),
      dataConcretagem: Parse.date(map['data_concretagem']),
      dataEstoque: Parse.date(map['data_estoque']),
      dataCarregamento: Parse.date(map['data_carregamento']),
      dataMontagem: Parse.date(map['data_montagem']),
    );
  }
}
