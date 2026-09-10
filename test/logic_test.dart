import 'package:flutter_test/flutter_test.dart';
import 'package:promold_app/core/logic/peca_calc.dart';
import 'package:promold_app/core/logic/status_config.dart';
import 'package:promold_app/models/obra_peca.dart';
import 'package:promold_app/models/peca_catalogo.dart';

ObraPeca peca({
  String status = 'pendente',
  num? largura,
  num? altura,
  num? comprimento,
  num? diametro,
  num? volPorMetro,
  num? kgAco,
  String tipoCalculo = 'linear',
}) {
  return ObraPeca(
    id: 'p1',
    obraId: 'o1',
    status: status,
    largura: largura,
    altura: altura,
    comprimento: comprimento,
    diametro: diametro,
    volumeConcretoPorMetro: volPorMetro,
    kgAcoPorMetro: kgAco,
    pecaCatalogo: PecaCatalogo(
      id: 'c1',
      nome: 'Viga',
      tipoCalculo: tipoCalculo,
    ),
  );
}

void main() {
  group('calcularPeca', () {
    test('linear: volume = L×A×C, peso = vol×2500', () {
      final r = calcularPeca(
        peca(largura: 0.3, altura: 0.4, comprimento: 5, kgAco: 100),
      );
      expect(r.tipo, 'linear');
      expect(round3(r.volume), 0.6);
      expect(r.peso, 1500);
      expect(r.aco, 60);
    });

    test('não linear: volume = vol/m × C', () {
      final r = calcularPeca(
        peca(tipoCalculo: 'nao_linear', volPorMetro: 0.1, comprimento: 10),
      );
      expect(r.volume, closeTo(1.0, 1e-9));
    });

    test('cilíndrica: volume = π·(D/2)²·C', () {
      final r = calcularPeca(
        peca(tipoCalculo: 'cilindrica', diametro: 0.5, comprimento: 3),
      );
      expect(r.volume, closeTo(0.589, 0.001));
    });
  });

  group('computeProgressoGeral', () {
    test('média ponderada dos status das peças', () {
      final pecas = [
        peca(status: 'armada'),
        peca(status: 'montada'),
      ];
      final pct = computeProgressoGeral(
        obraId: 'o1',
        pecas: pecas,
        processos: const [],
        etapasItens: const [],
        etapaStatus: const [],
      );
      // (25 + 100) / 2 = 62.5 -> 63
      expect(pct, 63);
    });

    test('sem peças retorna 0', () {
      final pct = computeProgressoGeral(
        obraId: 'o1',
        pecas: const [],
        processos: const [],
        etapasItens: const [],
        etapaStatus: const [],
      );
      expect(pct, 0);
    });
  });

  group('status helpers', () {
    test('normaliza status desconhecido para pendente', () {
      expect(normalizarStatus('aguardando'), 'pendente');
      expect(normalizarStatus(null), 'pendente');
      expect(normalizarStatus('em_estoque'), 'em_estoque');
    });

    test('statusConcluido reconhece em_estoque e montada', () {
      expect(statusConcluido('em_estoque'), isTrue);
      expect(statusConcluido('montada'), isTrue);
      expect(statusConcluido('concretada'), isFalse);
    });

    test('hexToColor converte com e sem cerquilha', () {
      expect(hexToColor('#10B981'), hexToColor('10B981'));
      expect(hexToColor('invalido'), isNull);
    });
  });
}
