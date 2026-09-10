/// Estruturas de dados do Painel da Fábrica.
class PainelDiaResumo {
  const PainelDiaResumo({
    required this.dia,
    required this.diaStr,
    required this.diaNome,
    required this.planejado,
    required this.produzido,
    required this.isHoje,
  });

  final DateTime dia;
  final String diaStr;
  final String diaNome;
  final int planejado;
  final int produzido;
  final bool isHoje;

  int get percentual =>
      planejado > 0 ? ((produzido / planejado) * 100).round() : 0;
}

class PainelPeca {
  const PainelPeca({
    required this.obraPecaId,
    required this.obraId,
    required this.identificador,
    this.largura,
    this.altura,
    this.comprimento,
    this.produzido = false,
    this.status,
  });

  final String? obraPecaId;
  final String obraId;
  final String identificador;
  final num? largura;
  final num? altura;
  final num? comprimento;
  final bool produzido;
  final String? status;

  String get dimensoes {
    final dims = <String>[
      if (largura != null) '$largura',
      if (altura != null) '$altura',
      if (comprimento != null) '$comprimento',
    ];
    return dims.isEmpty ? '—' : '${dims.join('×')}m';
  }
}

class PainelTipoDia {
  const PainelTipoDia({
    required this.pecaCatalogoId,
    required this.pecaNome,
    required this.pieces,
  });

  final String pecaCatalogoId;
  final String pecaNome;
  final List<PainelPeca> pieces;
}

class PainelObraDia {
  const PainelObraDia({
    required this.obraId,
    required this.obraNome,
    required this.total,
    required this.produzido,
    required this.tipos,
    this.obraCor,
  });

  final String obraId;
  final String obraNome;
  final String? obraCor;
  final int total;
  final int produzido;
  final List<PainelTipoDia> tipos;

  bool get completa => total > 0 && produzido >= total;
}

class PainelObraResumo {
  const PainelObraResumo({
    required this.obraId,
    required this.nome,
    required this.totalPecas,
    required this.produzido,
    required this.pendente,
    required this.percentual,
    required this.needsAttention,
    this.endereco,
    this.cor,
  });

  final String obraId;
  final String nome;
  final String? endereco;
  final String? cor;
  final int totalPecas;
  final int produzido;
  final int pendente;
  final int percentual;
  final bool needsAttention;
}

/// Conjunto consolidado exibido no Painel.
class PainelDados {
  const PainelDados({
    required this.diasSemana,
    required this.obrasDoDia,
    required this.obrasResumo,
    required this.planejadoDia,
    required this.producaoDia,
    required this.planejadoSemana,
    required this.producaoSemana,
  });

  final List<PainelDiaResumo> diasSemana;
  final List<PainelObraDia> obrasDoDia;
  final List<PainelObraResumo> obrasResumo;
  final int planejadoDia;
  final int producaoDia;
  final int planejadoSemana;
  final int producaoSemana;

  int get pendenteDia => (planejadoDia - producaoDia).clamp(0, 1 << 31);
  int get pendenteSemana =>
      (planejadoSemana - producaoSemana).clamp(0, 1 << 31);
  int get percentualDia =>
      planejadoDia > 0 ? ((producaoDia / planejadoDia) * 100).round() : 0;
  int get percentualSemana => planejadoSemana > 0
      ? ((producaoSemana / planejadoSemana) * 100).round()
      : 0;

  static const empty = PainelDados(
    diasSemana: <PainelDiaResumo>[],
    obrasDoDia: <PainelObraDia>[],
    obrasResumo: <PainelObraResumo>[],
    planejadoDia: 0,
    producaoDia: 0,
    planejadoSemana: 0,
    producaoSemana: 0,
  );
}
