import 'dart:math' as math;

import '../../models/obra_peca.dart';
import '../../models/peca_catalogo.dart';

/// Porte de `src/lib/pecaCalc.ts`.
///
/// Volume/peso/aço de uma peça, com três tipos de cálculo:
/// linear (L×A×C), não linear (vol/m × C) e cilíndrica (π·(D/2)²·C).
const double pesoConcretoKgM3 = 2500;

double round3(num? n) {
  final v = (n ?? 0).toDouble();
  if (!v.isFinite) return 0;
  return (v * 1000).round() / 1000;
}

String tipoCalculoDaPeca(ObraPeca p) {
  final cat = p.pecaCatalogo;
  final tc = cat?.tipoCalculo;
  if (tc == 'linear' || tc == 'nao_linear' || tc == 'cilindrica') {
    return tc!;
  }
  final diametro = (p.diametro ?? cat?.diametroPadrao ?? 0).toDouble();
  if (diametro > 0) return 'cilindrica';
  final largura = (p.largura ?? cat?.larguraPadrao ?? 0).toDouble();
  final altura = (p.altura ?? cat?.alturaPadrao ?? 0).toDouble();
  if (largura > 0 && altura > 0) return 'linear';
  final vpm =
      (p.volumeConcretoPorMetro ?? cat?.volumeConcretoPorMetro ?? 0).toDouble();
  if (vpm > 0) return 'nao_linear';
  return 'linear';
}

/// Determina o tipo a partir de catálogo + dimensões soltas (usado no editor).
String tipoCalculoPorValores({
  PecaCatalogo? catalogo,
  num? largura,
  num? altura,
  num? diametro,
  num? volumePorMetro,
}) {
  final tc = catalogo?.tipoCalculo;
  if (tc == 'linear' || tc == 'nao_linear' || tc == 'cilindrica') return tc!;
  final d = (diametro ?? catalogo?.diametroPadrao ?? 0).toDouble();
  if (d > 0) return 'cilindrica';
  final l = (largura ?? catalogo?.larguraPadrao ?? 0).toDouble();
  final a = (altura ?? catalogo?.alturaPadrao ?? 0).toDouble();
  if (l > 0 && a > 0) return 'linear';
  final v = (volumePorMetro ?? catalogo?.volumeConcretoPorMetro ?? 0).toDouble();
  if (v > 0) return 'nao_linear';
  return 'linear';
}

class PecaCalcResult {
  const PecaCalcResult({
    required this.tipo,
    required this.volume,
    required this.peso,
    required this.aco,
    required this.hasMissingDims,
  });

  final String tipo;
  final double volume;
  final double peso;
  final double aco;
  final bool hasMissingDims;

  bool get isLinear => tipo == 'linear';
}

PecaCalcResult calcularPeca(ObraPeca p) {
  final base = (p.largura ?? 0).toDouble();
  final altura = (p.altura ?? 0).toDouble();
  final comp = (p.comprimento ?? 0).toDouble();
  final diametro = (p.diametro ?? 0).toDouble();
  final volPorMetro = (p.volumeConcretoPorMetro ?? 0).toDouble();
  final taxaAco = (p.kgAcoPorMetro ?? 0).toDouble();
  final tipo = tipoCalculoDaPeca(p);

  double volume = 0;
  bool hasMissingDims;
  if (tipo == 'cilindrica') {
    if (diametro > 0 && comp > 0) {
      final r = diametro / 2;
      volume = math.pi * r * r * comp;
    } else if (p.volumeConcreto != null) {
      volume = p.volumeConcreto!.toDouble();
    }
    hasMissingDims = !(diametro > 0 && comp > 0);
  } else if (tipo == 'nao_linear') {
    if (volPorMetro > 0 && comp > 0) {
      volume = comp * volPorMetro;
    } else if (p.volumeConcreto != null) {
      volume = p.volumeConcreto!.toDouble();
    }
    hasMissingDims = !(volPorMetro > 0 && comp > 0);
  } else {
    if (base > 0 && altura > 0 && comp > 0) {
      volume = base * altura * comp;
    } else if (p.volumeConcreto != null) {
      volume = p.volumeConcreto!.toDouble();
    }
    hasMissingDims = !(base > 0 && altura > 0 && comp > 0);
  }

  return PecaCalcResult(
    tipo: tipo,
    volume: volume,
    peso: volume * pesoConcretoKgM3,
    aco: volume * taxaAco,
    hasMissingDims: hasMissingDims,
  );
}

/// Calcula volume/peso/aço a partir de valores soltos (editor/bulk).
PecaCalcResult calcularPorValores({
  PecaCatalogo? catalogo,
  num? largura,
  num? altura,
  num? comprimento,
  num? diametro,
  num? volumePorMetro,
  num? kgAcoPorMetro,
  num? volumeConcreto,
}) {
  final tipo = tipoCalculoPorValores(
    catalogo: catalogo,
    largura: largura,
    altura: altura,
    diametro: diametro,
    volumePorMetro: volumePorMetro,
  );
  final base = (largura ?? 0).toDouble();
  final alt = (altura ?? 0).toDouble();
  final comp = (comprimento ?? 0).toDouble();
  final d = (diametro ?? 0).toDouble();
  final vpm = (volumePorMetro ?? 0).toDouble();
  final taxaAco = (kgAcoPorMetro ?? 0).toDouble();

  double volume = 0;
  if (tipo == 'cilindrica' && d > 0 && comp > 0) {
    final r = d / 2;
    volume = math.pi * r * r * comp;
  } else if (tipo == 'nao_linear' && vpm > 0 && comp > 0) {
    volume = comp * vpm;
  } else if (tipo == 'linear' && base > 0 && alt > 0 && comp > 0) {
    volume = base * alt * comp;
  } else if (volumeConcreto != null) {
    volume = volumeConcreto.toDouble();
  }

  return PecaCalcResult(
    tipo: tipo,
    volume: volume,
    peso: volume * pesoConcretoKgM3,
    aco: volume * taxaAco,
    hasMissingDims: volume <= 0,
  );
}
