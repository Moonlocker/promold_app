import '../core/utils/parse.dart';
import 'peca_catalogo.dart';

/// Peça individual de uma obra (tabela `obras_pecas`), com o catálogo aninhado.
class ObraPeca {
  const ObraPeca({
    required this.id,
    required this.obraId,
    this.pecaCatalogoId,
    this.identificador = '',
    this.status = 'pendente',
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
    this.observacoes,
    this.valoresPersonalizados = const {},
    this.qcLoteId,
    this.estoqueId,
    this.compartimentoId,
    this.carregamentoId,
    this.pdfUrl,
    this.pdfStoragePath,
    this.inativada = false,
    this.ifcArquivoId,
    this.ifcExpressId,
    this.ifcGlobalId,
    this.ifcMetadata = const {},
    this.createdAt,
    this.updatedAt,
    this.pecaCatalogo,
  });

  final String id;
  final String obraId;
  final String? pecaCatalogoId;
  final String identificador;
  final String status;
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
  final String? observacoes;
  final Map<String, dynamic> valoresPersonalizados;
  final String? qcLoteId;
  final String? estoqueId;
  final String? compartimentoId;
  final String? carregamentoId;
  final String? pdfUrl;
  final String? pdfStoragePath;
  final bool inativada;
  final String? ifcArquivoId;
  final int? ifcExpressId;
  final String? ifcGlobalId;
  final Map<String, dynamic> ifcMetadata;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final PecaCatalogo? pecaCatalogo;

  String get nomePeca => pecaCatalogo?.nome ?? 'Peça';
  bool get isProtendido => pecaCatalogo?.isProtendido ?? false;
  String get tipoConcretoLabel => isProtendido ? 'P' : 'A';

  factory ObraPeca.fromMap(Map<String, dynamic> map) {
    return ObraPeca(
      id: map['id'] as String,
      obraId: (map['obra_id'] as String?) ?? '',
      pecaCatalogoId: map['peca_catalogo_id'] as String?,
      identificador: (map['identificador'] as String?) ?? '',
      status: (map['status'] as String?) ?? 'pendente',
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
      observacoes: map['observacoes'] as String?,
      valoresPersonalizados: Parse.map(map['valores_personalizados']),
      qcLoteId: map['qc_lote_id'] as String?,
      estoqueId: map['estoque_id'] as String?,
      compartimentoId: map['compartimento_id'] as String?,
      carregamentoId: map['carregamento_id'] as String?,
      pdfUrl: map['pdf_url'] as String?,
      pdfStoragePath: map['pdf_storage_path'] as String?,
      inativada: (map['inativada'] as bool?) ?? false,
      ifcArquivoId: map['ifc_arquivo_id'] as String?,
      ifcExpressId: (map['ifc_express_id'] as num?)?.toInt(),
      ifcGlobalId: map['ifc_global_id'] as String?,
      ifcMetadata: Parse.map(map['ifc_metadata']),
      createdAt: Parse.date(map['created_at']),
      updatedAt: Parse.date(map['updated_at']),
      pecaCatalogo: map['pecas_catalogo'] is Map
          ? PecaCatalogo.fromMap(
              Map<String, dynamic>.from(map['pecas_catalogo'] as Map))
          : null,
    );
  }
}
