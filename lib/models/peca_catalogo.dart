import 'categoria_peca.dart';

/// Tipo de peça no catálogo (tabela `pecas_catalogo`).
class PecaCatalogo {
  const PecaCatalogo({
    required this.id,
    required this.nome,
    this.categoriaId,
    this.descricao,
    this.unidade = 'un',
    this.pesoPadrao,
    this.volumeConcretoPadrao,
    this.ativa = true,
    this.custoUnitario,
    this.larguraPadrao,
    this.espessuraPadrao,
    this.identificadorPadrao,
    this.alturaPadrao,
    this.volumeConcretoPorMetro,
    this.comprimentoPadrao,
    this.kgAcoPorMetro,
    this.camposPersonalizados = const [],
    this.tipoConcreto = 'armado',
    this.tipoCalculo = 'linear',
    this.diametroPadrao,
    this.categoria,
  });

  final String id;
  final String nome;
  final String? categoriaId;
  final String? descricao;
  final String unidade;
  final num? pesoPadrao;
  final num? volumeConcretoPadrao;
  final bool ativa;
  final num? custoUnitario;
  final num? larguraPadrao;
  final num? espessuraPadrao;
  final String? identificadorPadrao;
  final num? alturaPadrao;
  final num? volumeConcretoPorMetro;
  final num? comprimentoPadrao;
  final num? kgAcoPorMetro;
  final List<Map<String, dynamic>> camposPersonalizados;
  final String tipoConcreto;
  final String tipoCalculo;
  final num? diametroPadrao;
  final CategoriaPeca? categoria;

  bool get isProtendido => tipoConcreto == 'protendido';
  String get tipoConcretoLabel => isProtendido ? 'Protendido' : 'Armado';

  factory PecaCatalogo.fromMap(Map<String, dynamic> map) {
    return PecaCatalogo(
      id: map['id'] as String,
      nome: (map['nome'] as String?) ?? 'Peça',
      categoriaId: map['categoria_id'] as String?,
      descricao: map['descricao'] as String?,
      unidade: (map['unidade'] as String?) ?? 'un',
      pesoPadrao: map['peso_padrao'] as num?,
      volumeConcretoPadrao: map['volume_concreto_padrao'] as num?,
      ativa: (map['ativa'] as bool?) ?? true,
      custoUnitario: map['custo_unitario'] as num?,
      larguraPadrao: map['largura_padrao'] as num?,
      espessuraPadrao: map['espessura_padrao'] as num?,
      identificadorPadrao: map['identificador_padrao'] as String?,
      alturaPadrao: map['altura_padrao'] as num?,
      volumeConcretoPorMetro: map['volume_concreto_por_metro'] as num?,
      comprimentoPadrao: map['comprimento_padrao'] as num?,
      kgAcoPorMetro: map['kg_aco_por_metro'] as num?,
      camposPersonalizados: (map['campos_personalizados'] as List? ?? [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList(),
      tipoConcreto: (map['tipo_concreto'] as String?) ?? 'armado',
      tipoCalculo: (map['tipo_calculo'] as String?) ?? 'linear',
      diametroPadrao: map['diametro_padrao'] as num?,
      categoria: map['categorias_peca'] is Map
          ? CategoriaPeca.fromMap(
              Map<String, dynamic>.from(map['categorias_peca'] as Map))
          : null,
    );
  }
}
