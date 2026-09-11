/// Modelos do módulo Qualidade.
class QcLote {
  const QcLote({
    required this.id,
    required this.codigo,
    required this.dataConcretagem,
    required this.fckMpa,
    this.traco,
    this.tracoFck,
    this.slump,
    this.volumeM3,
    this.fornecedor,
    this.fornecedorId,
    this.responsavel,
    this.laboratorista,
    this.horaMoldagem,
    this.horaAplicacao,
    this.formaProducao,
    this.fcjMpa,
    this.colocadoEmForma,
    this.obraId,
    this.observacoes,
  });

  final String id;
  final String codigo;
  final String dataConcretagem;
  final double fckMpa;
  final String? traco;
  final double? tracoFck;
  final String? slump;
  final double? volumeM3;
  final String? fornecedor;
  final String? fornecedorId;
  final String? responsavel;
  final String? laboratorista;
  final String? horaMoldagem;
  final String? horaAplicacao;
  final String? formaProducao;
  final double? fcjMpa;
  final bool? colocadoEmForma;
  final String? obraId;
  final String? observacoes;

  static double _d(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }

  static double? _dn(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  factory QcLote.fromMap(Map<String, dynamic> m) => QcLote(
        id: m['id'] as String,
        codigo: (m['codigo'] as String?) ?? '',
        dataConcretagem: (m['data_concretagem'] as String?) ?? '',
        fckMpa: _d(m['fck_mpa']),
        traco: m['traco'] as String?,
        tracoFck: _dn(m['traco_fck']),
        slump: m['slump'] as String?,
        volumeM3: _dn(m['volume_m3']),
        fornecedor: m['fornecedor'] as String?,
        fornecedorId: m['fornecedor_id'] as String?,
        responsavel: m['responsavel'] as String?,
        laboratorista: m['laboratorista'] as String?,
        horaMoldagem: m['hora_moldagem'] as String?,
        horaAplicacao: m['hora_aplicacao'] as String?,
        formaProducao: m['forma_producao'] as String?,
        fcjMpa: _dn(m['fcj_mpa']),
        colocadoEmForma: m['colocado_em_forma'] as bool?,
        obraId: m['obra_id'] as String?,
        observacoes: m['observacoes'] as String?,
      );
}

class QcCorpoProva {
  const QcCorpoProva({
    required this.id,
    required this.loteId,
    required this.identificador,
    required this.dataMoldagem,
    required this.idadeRompimentoDias,
    this.dataPrevistaRompimento,
    this.observacoes,
    this.grupo,
    this.idadeHoras,
    this.templateSlug,
  });

  final String id;
  final String loteId;
  final String identificador;
  final String dataMoldagem;
  final int idadeRompimentoDias;
  final String? dataPrevistaRompimento;
  final String? observacoes;
  final String? grupo;
  final int? idadeHoras;
  final String? templateSlug;

  factory QcCorpoProva.fromMap(Map<String, dynamic> m) => QcCorpoProva(
        id: m['id'] as String,
        loteId: m['lote_id'] as String,
        identificador: (m['identificador'] as String?) ?? '',
        dataMoldagem: (m['data_moldagem'] as String?) ?? '',
        idadeRompimentoDias: (m['idade_rompimento_dias'] as num?)?.toInt() ?? 0,
        dataPrevistaRompimento: m['data_prevista_rompimento'] as String?,
        observacoes: m['observacoes'] as String?,
        grupo: m['grupo'] as String?,
        idadeHoras: (m['idade_horas'] as num?)?.toInt(),
        templateSlug: m['template_slug'] as String?,
      );
}

class QcEnsaio {
  const QcEnsaio({
    required this.id,
    required this.corpoProvaId,
    required this.dataEnsaio,
    required this.resistenciaMpa,
    this.idadeRealDias,
    this.laboratorio,
    this.aprovado,
    this.laudoUrl,
    this.observacoes,
    this.horaRuptura,
    this.cargaKn,
    this.tensaoMpa,
  });

  final String id;
  final String corpoProvaId;
  final String dataEnsaio;
  final double resistenciaMpa;
  final int? idadeRealDias;
  final String? laboratorio;
  final bool? aprovado;
  final String? laudoUrl;
  final String? observacoes;
  final String? horaRuptura;
  final double? cargaKn;
  final double? tensaoMpa;

  static double _d(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }

  static double? _dn(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  factory QcEnsaio.fromMap(Map<String, dynamic> m) => QcEnsaio(
        id: m['id'] as String,
        corpoProvaId: m['corpo_prova_id'] as String,
        dataEnsaio: (m['data_ensaio'] as String?) ?? '',
        resistenciaMpa: _d(m['resistencia_mpa']),
        idadeRealDias: (m['idade_real_dias'] as num?)?.toInt(),
        laboratorio: m['laboratorio'] as String?,
        aprovado: m['aprovado'] as bool?,
        laudoUrl: m['laudo_url'] as String?,
        observacoes: m['observacoes'] as String?,
        horaRuptura: m['hora_ruptura'] as String?,
        cargaKn: _dn(m['carga_kn']),
        tensaoMpa: _dn(m['tensao_mpa']),
      );
}

class QcPadrao {
  const QcPadrao({
    required this.id,
    required this.tipo,
    required this.padrao,
    this.sigla,
    this.contadorAtual = 0,
    this.contadorReset = 'diario',
    this.ultimoResetData,
  });

  final String id;
  final String tipo; // 'lote' | 'corpo_prova'
  final String padrao;
  final String? sigla;
  final int contadorAtual;
  final String contadorReset;
  final String? ultimoResetData;

  factory QcPadrao.fromMap(Map<String, dynamic> m) => QcPadrao(
        id: m['id'] as String,
        tipo: (m['tipo'] as String?) ?? 'lote',
        padrao: (m['padrao'] as String?) ?? '',
        sigla: m['sigla'] as String?,
        contadorAtual: (m['contador_atual'] as num?)?.toInt() ?? 0,
        contadorReset: (m['contador_reset'] as String?) ?? 'diario',
        ultimoResetData: m['ultimo_reset_data'] as String?,
      );
}
