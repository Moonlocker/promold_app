import '../../models/obra.dart';
import '../../models/obra_peca.dart';
import '../../models/peca_catalogo.dart';
import '../../models/planejamento_semanal.dart';
import '../../models/producao_indicadores.dart';
import 'peca_calc.dart';
import 'status_config.dart';

/// Cálculos dos Indicadores (porte de `src/pages/Producao.tsx`).
///
/// Funções puras para permitir testes sem rede.

const List<String> producaoStatusOrdem = [
  'pendente',
  'armada',
  'concretada',
  'em_estoque',
  'montada',
];

String _iso(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

String _label(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';

double _round3(num n) => (n * 1000).round() / 1000;
double _round2(num n) => (n * 100).round() / 100;

/// Soma volume e aço de uma lista de peças (usa `calcularPeca`).
({double volume, double aco}) somarInsumos(List<ObraPeca> registros) {
  var volume = 0.0;
  var aco = 0.0;
  for (final r in registros) {
    final c = calcularPeca(r);
    volume += c.volume;
    aco += c.aco;
  }
  return (volume: volume, aco: aco);
}

/// Agrupa a produção por tipo de peça (nome do catálogo), do maior para o menor.
List<MapEntry<String, int>> agruparPorTipo(List<ObraPeca> registros) {
  final map = <String, int>{};
  for (final r in registros) {
    final nome = r.pecaCatalogo?.nome ?? 'Desconhecido';
    map[nome] = (map[nome] ?? 0) + 1;
  }
  final list = map.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
  return list;
}

PecaCalcResult _calcPlanejado(
  PlanejamentoSemanal p,
  Map<String, ObraPeca> pecasPorId,
  Map<String, PecaCatalogo> catalogoPorId,
) {
  final piece = p.obraPecaId != null ? pecasPorId[p.obraPecaId] : null;
  final pc =
      piece?.pecaCatalogo ??
      (p.pecaCatalogoId != null ? catalogoPorId[p.pecaCatalogoId] : null);
  return calcularPorValores(
    catalogo: pc,
    largura: piece?.largura ?? pc?.larguraPadrao,
    altura: piece?.altura ?? pc?.alturaPadrao,
    comprimento: piece?.comprimento ?? pc?.comprimentoPadrao,
    diametro: piece?.diametro ?? pc?.diametroPadrao,
    volumePorMetro: piece?.volumeConcretoPorMetro ?? pc?.volumeConcretoPorMetro,
    kgAcoPorMetro: piece?.kgAcoPorMetro ?? pc?.kgAcoPorMetro,
  );
}

/// Série diária do período: produzido x planejado, com volume/aço.
List<ProducaoDia> construirChartDiario({
  required List<ObraPeca> registros,
  required List<PlanejamentoSemanal> planejamentos,
  required List<ObraPeca> pecasPlanejadas,
  required List<PecaCatalogo> catalogo,
  required DateTime inicio,
  required DateTime fim,
}) {
  final registrosPorDia = <String, List<ObraPeca>>{};
  for (final r in registros) {
    final d = r.dataConcretagem;
    if (d == null) continue;
    registrosPorDia.putIfAbsent(_iso(d), () => []).add(r);
  }

  final pecasPorId = {for (final p in pecasPlanejadas) p.id: p};
  final catalogoPorId = {for (final c in catalogo) c.id: c};

  final planPorDia = <String, ({int count, double volume, double aco})>{};
  for (final p in planejamentos) {
    final di = DateTime.tryParse(p.dataInicio);
    final df = DateTime.tryParse(p.dataFim);
    if (di == null || df == null) continue;
    final start = di.isBefore(inicio) ? inicio : di;
    final end = df.isAfter(fim) ? fim : df;
    final calc = _calcPlanejado(p, pecasPorId, catalogoPorId);
    for (
      var d = DateTime(start.year, start.month, start.day);
      !d.isAfter(end);
      d = d.add(const Duration(days: 1))
    ) {
      final key = _iso(d);
      final atual = planPorDia[key] ?? (count: 0, volume: 0.0, aco: 0.0);
      planPorDia[key] = (
        count: atual.count + 1,
        volume: atual.volume + calc.volume,
        aco: atual.aco + calc.aco,
      );
    }
  }

  final dias = <ProducaoDia>[];
  for (
    var d = DateTime(inicio.year, inicio.month, inicio.day);
    !d.isAfter(fim);
    d = d.add(const Duration(days: 1))
  ) {
    final key = _iso(d);
    final regs = registrosPorDia[key] ?? const <ObraPeca>[];
    final soma = somarInsumos(regs);
    final plan = planPorDia[key];
    dias.add(
      ProducaoDia(
        date: key,
        label: _label(d),
        pecas: regs.length,
        planejado: plan?.count ?? 0,
        concreto: _round3(soma.volume),
        aco: _round2(soma.aco),
        concretoPlan: _round3(plan?.volume ?? 0),
        acoPlan: _round2(plan?.aco ?? 0),
      ),
    );
  }
  return dias;
}

/// Matriz de progresso por obra (contagem exata por status atual).
List<ObraProgresso> construirProgressoObras({
  required List<Obra> obras,
  required List<ObraPeca> pecas,
  Set<String> obrasFiltro = const {},
  Set<String> categoriasFiltro = const {},
  Set<String> pecasFiltro = const {},
  Map<String, PecaCatalogo> catalogoPorId = const {},
}) {
  final resultado = <ObraProgresso>[];
  for (final obra in obras) {
    if (obra.status != 'ativa' && obra.status != 'planejamento') continue;
    if (obrasFiltro.isNotEmpty && !obrasFiltro.contains(obra.id)) continue;

    final pecasObra = pecas.where((p) {
      if (p.obraId != obra.id) return false;
      final pc = p.pecaCatalogoId != null
          ? catalogoPorId[p.pecaCatalogoId]
          : null;
      if (categoriasFiltro.isNotEmpty) {
        final catId = pc?.categoriaId;
        if (catId == null || !categoriasFiltro.contains(catId)) return false;
      }
      if (pecasFiltro.isNotEmpty && !pecasFiltro.contains(p.pecaCatalogoId)) {
        return false;
      }
      return true;
    }).toList();

    if (pecasObra.isEmpty) continue;

    final counts = <String, int>{for (final s in producaoStatusOrdem) s: 0};
    for (final p in pecasObra) {
      final s = normalizarStatus(p.status);
      counts[s] = (counts[s] ?? 0) + 1;
    }

    resultado.add(
      ObraProgresso(
        obraId: obra.id,
        nome: obra.nome,
        cor: obra.cor,
        total: pecasObra.length,
        counts: counts,
      ),
    );
  }
  return resultado;
}
