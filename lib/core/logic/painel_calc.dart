import '../../models/obra.dart';
import '../../models/obra_peca.dart';
import '../../models/painel_fabrica.dart';
import '../../models/peca_catalogo.dart';
import '../../models/planejamento_semanal.dart';
import '../utils/formatters.dart';

/// Cálculos do Painel da Fábrica (porte de `src/pages/PainelFabrica.tsx`).

const List<String> _diasAbrev = [
  'dom',
  'seg',
  'ter',
  'qua',
  'qui',
  'sex',
  'sáb',
];

/// Domingo (início da semana) da data informada.
DateTime inicioDaSemana(DateTime d) {
  final base = DateTime(d.year, d.month, d.day);
  return base.subtract(Duration(days: d.weekday % 7));
}

/// "Realizado" depende do painel (armação x produção).
bool isRealizadoStatus(String? status, bool isArmacao) {
  if (status == null) return false;
  const adiante = [
    'armada',
    'concretada',
    'em_estoque',
    'aguardando',
    'montada',
  ];
  const producao = ['concretada', 'em_estoque', 'aguardando', 'montada'];
  return (isArmacao ? adiante : producao).contains(status);
}

List<PainelDiaResumo> construirDiasResumo({
  required DateTime inicio,
  required List<PlanejamentoSemanal> planejamentos,
  required Map<String, ObraPeca> pecasPorId,
  required bool isArmacao,
  required DateTime hoje,
}) {
  final hojeStr = Formatters.iso(hoje);
  final dias = <PainelDiaResumo>[];
  for (var i = 0; i < 7; i++) {
    final dia = inicio.add(Duration(days: i));
    final diaStr = Formatters.iso(dia);
    var plan = 0;
    var prod = 0;
    for (final p in planejamentos) {
      if (p.dataInicio.compareTo(diaStr) <= 0 &&
          p.dataFim.compareTo(diaStr) >= 0) {
        plan++;
        final piece = p.obraPecaId != null ? pecasPorId[p.obraPecaId] : null;
        if (piece != null && isRealizadoStatus(piece.status, isArmacao)) {
          prod++;
        }
      }
    }
    dias.add(
      PainelDiaResumo(
        dia: dia,
        diaStr: diaStr,
        diaNome: _diasAbrev[dia.weekday % 7],
        planejado: plan,
        produzido: prod,
        isHoje: diaStr == hojeStr,
      ),
    );
  }
  return dias;
}

List<PainelObraDia> construirObrasDoDia({
  required String diaStr,
  required List<PlanejamentoSemanal> planejamentos,
  required Map<String, ObraPeca> pecasPorId,
  required Map<String, Obra> obrasPorId,
  required Map<String, PecaCatalogo> catalogoPorId,
  required bool isArmacao,
}) {
  final porObra = <String, _ObraBuilder>{};

  for (final plan in planejamentos) {
    if (plan.obraId == null || plan.pecaCatalogoId == null) continue;
    if (plan.dataInicio.compareTo(diaStr) > 0 ||
        plan.dataFim.compareTo(diaStr) < 0) {
      continue;
    }
    final piece = plan.obraPecaId != null ? pecasPorId[plan.obraPecaId] : null;
    final peca = catalogoPorId[plan.pecaCatalogoId];
    final obra = obrasPorId[plan.obraId];
    final produzido = isRealizadoStatus(piece?.status, isArmacao);

    final og = porObra.putIfAbsent(
      plan.obraId!,
      () => _ObraBuilder(
        obraId: plan.obraId!,
        obraNome: obra?.nome ?? 'Obra',
        obraCor: obra?.cor,
      ),
    );
    og.total++;
    if (produzido) og.produzido++;

    final tipo = og.tipos.putIfAbsent(
      plan.pecaCatalogoId!,
      () => _TipoBuilder(
        pecaCatalogoId: plan.pecaCatalogoId!,
        pecaNome: peca?.nome ?? 'Peça',
      ),
    );
    tipo.pieces.add(
      PainelPeca(
        obraPecaId: plan.obraPecaId,
        obraId: plan.obraId!,
        identificador: piece?.identificador.isNotEmpty == true
            ? piece!.identificador
            : (plan.obraPecaId != null
                  ? '#${plan.obraPecaId!.substring(0, 8)}'
                  : 'Sem ID'),
        largura: piece?.largura,
        altura: piece?.altura,
        comprimento: piece?.comprimento,
        produzido: produzido,
        status: piece?.status,
      ),
    );
  }

  return porObra.values
      .map(
        (og) => PainelObraDia(
          obraId: og.obraId,
          obraNome: og.obraNome,
          obraCor: og.obraCor,
          total: og.total,
          produzido: og.produzido,
          tipos: og.tipos.values
              .map(
                (t) => PainelTipoDia(
                  pecaCatalogoId: t.pecaCatalogoId,
                  pecaNome: t.pecaNome,
                  pieces: t.pieces,
                ),
              )
              .toList(),
        ),
      )
      .toList();
}

class _ObraBuilder {
  _ObraBuilder({required this.obraId, required this.obraNome, this.obraCor});

  final String obraId;
  final String obraNome;
  final String? obraCor;
  int total = 0;
  int produzido = 0;
  final Map<String, _TipoBuilder> tipos = {};
}

class _TipoBuilder {
  _TipoBuilder({required this.pecaCatalogoId, required this.pecaNome});

  final String pecaCatalogoId;
  final String pecaNome;
  final List<PainelPeca> pieces = [];
}
