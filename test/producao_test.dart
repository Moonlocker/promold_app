import 'package:flutter_test/flutter_test.dart';
import 'package:promold_app/core/logic/producao_calc.dart';
import 'package:promold_app/core/utils/formatters.dart';
import 'package:promold_app/models/obra.dart';
import 'package:promold_app/models/obra_peca.dart';
import 'package:promold_app/models/peca_catalogo.dart';
import 'package:promold_app/models/planejamento_semanal.dart';

PecaCatalogo catalogo({
  String id = 'c1',
  String nome = 'Viga',
  String? categoriaId = 'cat1',
}) {
  return PecaCatalogo(
    id: id,
    nome: nome,
    categoriaId: categoriaId,
    tipoCalculo: 'linear',
    larguraPadrao: 0.3,
    alturaPadrao: 0.4,
    comprimentoPadrao: 5,
    kgAcoPorMetro: 100,
  );
}

ObraPeca peca({
  required String id,
  required String obraId,
  String status = 'concretada',
  String? pecaCatalogoId = 'c1',
  DateTime? dataConcretagem,
  PecaCatalogo? cat,
}) {
  return ObraPeca(
    id: id,
    obraId: obraId,
    status: status,
    pecaCatalogoId: pecaCatalogoId,
    dataConcretagem: dataConcretagem,
    largura: 0.3,
    altura: 0.4,
    comprimento: 5,
    kgAcoPorMetro: 100,
    pecaCatalogo: cat ?? catalogo(id: pecaCatalogoId ?? 'c1'),
  );
}

Obra obra({
  required String id,
  String nome = 'Obra',
  String status = 'ativa',
  String? cor,
}) {
  return Obra(id: id, nome: nome, cliente: 'Cliente', status: status, cor: cor);
}

void main() {
  group('Formatters.numero', () {
    test('formata milhar e decimais no padrão pt-BR', () {
      expect(Formatters.numero(1234), '1.234');
      expect(Formatters.numero(1234.567, 2), '1.234,57');
      expect(Formatters.numero(null), '0');
    });
  });

  group('somarInsumos e agruparPorTipo', () {
    test('soma volume e aço das peças', () {
      final soma = somarInsumos([
        peca(id: 'p1', obraId: 'o1'),
        peca(id: 'p2', obraId: 'o1'),
      ]);
      // Cada peça: 0.3×0.4×5 = 0.6 m³ ; aço = 0.6×100 = 60 kg
      expect(soma.volume, closeTo(1.2, 1e-9));
      expect(soma.aco, closeTo(120, 1e-9));
    });

    test('agrupa por nome do catálogo, do maior para o menor', () {
      final lista = agruparPorTipo([
        peca(id: 'p1', obraId: 'o1', cat: catalogo(nome: 'Viga')),
        peca(id: 'p2', obraId: 'o1', cat: catalogo(nome: 'Viga')),
        peca(id: 'p3', obraId: 'o1', cat: catalogo(nome: 'Pilar')),
      ]);
      expect(lista.first.key, 'Viga');
      expect(lista.first.value, 2);
      expect(lista.last.key, 'Pilar');
    });
  });

  group('construirChartDiario', () {
    test('produzido x planejado por dia, com volume planejado', () {
      final chart = construirChartDiario(
        registros: [
          peca(
            id: 'p1',
            obraId: 'o1',
            dataConcretagem: DateTime(2026, 1, 5),
          ),
          peca(
            id: 'p2',
            obraId: 'o1',
            dataConcretagem: DateTime(2026, 1, 5),
          ),
          peca(
            id: 'p3',
            obraId: 'o1',
            dataConcretagem: DateTime(2026, 1, 6),
          ),
        ],
        planejamentos: [
          PlanejamentoSemanal(
            id: 'pl1',
            dataInicio: '2026-01-05',
            dataFim: '2026-01-07',
            pecaCatalogoId: 'c1',
          ),
        ],
        pecasPlanejadas: const [],
        catalogo: [catalogo()],
        inicio: DateTime(2026, 1, 5),
        fim: DateTime(2026, 1, 7),
      );

      expect(chart.length, 3);

      expect(chart[0].date, '2026-01-05');
      expect(chart[0].pecas, 2);
      expect(chart[0].planejado, 1);
      expect(chart[0].concretoPlan, closeTo(0.6, 1e-9));

      expect(chart[1].date, '2026-01-06');
      expect(chart[1].pecas, 1);

      expect(chart[2].date, '2026-01-07');
      expect(chart[2].pecas, 0);
      expect(chart[2].planejado, 1);
    });
  });

  group('construirProgressoObras', () {
    final obras = [
      obra(id: 'o1', nome: 'Ativa', status: 'ativa'),
      obra(id: 'o2', nome: 'Planejamento', status: 'planejamento'),
      obra(id: 'o3', nome: 'Pausada', status: 'pausada'),
    ];

    final pecas = [
      peca(id: 'p1', obraId: 'o1', status: 'pendente'),
      peca(id: 'p2', obraId: 'o1', status: 'montada'),
      peca(id: 'p3', obraId: 'o2', status: 'concretada'),
      peca(id: 'p4', obraId: 'o3', status: 'pendente'),
    ];

    test('inclui apenas obras ativas/planejamento com peças', () {
      final rows = construirProgressoObras(obras: obras, pecas: pecas);
      expect(rows.map((r) => r.obraId), ['o1', 'o2']);
      expect(rows.first.total, 2);
      expect(rows.first.counts['pendente'], 1);
      expect(rows.first.counts['montada'], 1);
    });

    test('filtro por obra restringe o resultado', () {
      final rows = construirProgressoObras(
        obras: obras,
        pecas: pecas,
        obrasFiltro: {'o2'},
      );
      expect(rows.length, 1);
      expect(rows.first.obraId, 'o2');
    });

    test('filtro por peça do catálogo', () {
      final comCatalogo = [
        peca(id: 'p1', obraId: 'o1', pecaCatalogoId: 'c1'),
        peca(id: 'p2', obraId: 'o1', pecaCatalogoId: 'c2'),
      ];
      final rows = construirProgressoObras(
        obras: obras,
        pecas: comCatalogo,
        pecasFiltro: {'c2'},
      );
      expect(rows.first.total, 1);
    });
  });
}
