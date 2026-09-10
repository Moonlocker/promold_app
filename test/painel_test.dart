import 'package:flutter_test/flutter_test.dart';
import 'package:promold_app/core/logic/painel_calc.dart';
import 'package:promold_app/models/obra.dart';
import 'package:promold_app/models/obra_peca.dart';
import 'package:promold_app/models/peca_catalogo.dart';
import 'package:promold_app/models/planejamento_semanal.dart';

ObraPeca peca({
  required String id,
  required String obraId,
  String status = 'pendente',
  String identificador = 'P1',
  String? pecaCatalogoId = 'c1',
}) {
  return ObraPeca(
    id: id,
    obraId: obraId,
    status: status,
    identificador: identificador,
    pecaCatalogoId: pecaCatalogoId,
    largura: 0.3,
    altura: 0.4,
    comprimento: 5,
    pecaCatalogo: PecaCatalogo(id: 'c1', nome: 'Viga'),
  );
}

PlanejamentoSemanal plano({
  required String id,
  required String dataInicio,
  required String dataFim,
  String obraId = 'o1',
  String pecaCatalogoId = 'c1',
  String? obraPecaId,
  String tipo = 'producao',
}) {
  return PlanejamentoSemanal(
    id: id,
    dataInicio: dataInicio,
    dataFim: dataFim,
    obraId: obraId,
    pecaCatalogoId: pecaCatalogoId,
    obraPecaId: obraPecaId,
    tipo: tipo,
  );
}

void main() {
  group('inicioDaSemana', () {
    test('retorna o domingo da semana', () {
      // 2026-01-07 é uma quarta-feira.
      final domingo = inicioDaSemana(DateTime(2026, 1, 7));
      expect(domingo, DateTime(2026, 1, 4));
    });

    test('domingo permanece no mesmo dia', () {
      expect(inicioDaSemana(DateTime(2026, 1, 4)), DateTime(2026, 1, 4));
    });
  });

  group('isRealizadoStatus', () {
    test('armação considera armada em diante', () {
      expect(isRealizadoStatus('pendente', true), isFalse);
      expect(isRealizadoStatus('armada', true), isTrue);
      expect(isRealizadoStatus('concretada', true), isTrue);
    });

    test('produção exige concretada em diante', () {
      expect(isRealizadoStatus('armada', false), isFalse);
      expect(isRealizadoStatus('concretada', false), isTrue);
      expect(isRealizadoStatus(null, false), isFalse);
    });
  });

  group('construirDiasResumo', () {
    test('conta planejado e realizado por dia', () {
      final pecas = {
        'p1': peca(id: 'p1', obraId: 'o1', status: 'concretada'),
        'p2': peca(id: 'p2', obraId: 'o1', status: 'pendente'),
      };
      final planejamentos = [
        plano(
          id: 'pl1',
          dataInicio: '2026-01-05',
          dataFim: '2026-01-05',
          obraPecaId: 'p1',
        ),
        plano(
          id: 'pl2',
          dataInicio: '2026-01-05',
          dataFim: '2026-01-05',
          obraPecaId: 'p2',
        ),
      ];

      final dias = construirDiasResumo(
        inicio: DateTime(2026, 1, 4),
        planejamentos: planejamentos,
        pecasPorId: pecas,
        isArmacao: false,
        hoje: DateTime(2026, 1, 5),
      );

      expect(dias.length, 7);
      final dia5 = dias.firstWhere((d) => d.diaStr == '2026-01-05');
      expect(dia5.planejado, 2);
      expect(dia5.produzido, 1);
      expect(dia5.percentual, 50);
      expect(dia5.isHoje, isTrue);
    });
  });

  group('construirObrasDoDia', () {
    test('agrupa por obra e por tipo de peça', () {
      final pecas = {
        'p1': peca(
          id: 'p1',
          obraId: 'o1',
          status: 'concretada',
          identificador: 'V1',
        ),
        'p2': peca(
          id: 'p2',
          obraId: 'o1',
          status: 'pendente',
          identificador: 'V2',
        ),
      };
      final planejamentos = [
        plano(
          id: 'pl1',
          dataInicio: '2026-01-05',
          dataFim: '2026-01-05',
          obraPecaId: 'p1',
        ),
        plano(
          id: 'pl2',
          dataInicio: '2026-01-05',
          dataFim: '2026-01-05',
          obraPecaId: 'p2',
        ),
      ];

      final obras = construirObrasDoDia(
        diaStr: '2026-01-05',
        planejamentos: planejamentos,
        pecasPorId: pecas,
        obrasPorId: {'o1': const Obra(id: 'o1', nome: 'Obra 1', cliente: 'C')},
        catalogoPorId: {'c1': const PecaCatalogo(id: 'c1', nome: 'Viga')},
        isArmacao: false,
      );

      expect(obras.length, 1);
      expect(obras.first.obraNome, 'Obra 1');
      expect(obras.first.total, 2);
      expect(obras.first.produzido, 1);
      expect(obras.first.tipos.length, 1);
      expect(obras.first.tipos.first.pieces.length, 2);
      expect(obras.first.tipos.first.pieces.first.produzido, isTrue);
    });
  });
}
