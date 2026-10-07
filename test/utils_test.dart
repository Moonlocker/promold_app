import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:promold_app/core/utils/date_input.dart';
import 'package:promold_app/core/utils/formatters.dart';
import 'package:promold_app/models/capacidade.dart';
import 'package:promold_app/models/dashboard_semana.dart';
import 'package:promold_app/models/sistema.dart';
import 'package:promold_app/services/orcamento_pdf_service.dart';
import 'package:promold_app/services/xlsx_service.dart';

void main() {
  group('normalizarDataBr', () {
    test('aceita ISO com e sem hora', () {
      expect(normalizarDataBr('2026-06-10'), '2026-06-10');
      expect(normalizarDataBr('2026-06-10T00:00:00.000Z'), '2026-06-10');
    });

    test('aceita dd/MM/yyyy e dd-MM-yyyy', () {
      expect(normalizarDataBr('10/06/2026'), '2026-06-10');
      expect(normalizarDataBr('10-06-2026'), '2026-06-10');
    });

    test('vazio vira null e formato desconhecido é preservado', () {
      expect(normalizarDataBr(''), isNull);
      expect(normalizarDataBr('   '), isNull);
      expect(normalizarDataBr('junho'), 'junho');
    });
  });

  group('Formatters extras', () {
    test('mesAno capitaliza o mês', () {
      expect(Formatters.mesAno(DateTime(2026, 10, 1)), 'Outubro de 2026');
    });

    test('tempoAtras formata intervalos', () {
      final agora = DateTime.now();
      expect(Formatters.tempoAtras(agora), 'agora');
      expect(Formatters.tempoAtras(agora.subtract(const Duration(minutes: 5))),
          'há 5 min');
      expect(Formatters.tempoAtras(agora.subtract(const Duration(hours: 3))),
          'há 3 h');
      expect(Formatters.tempoAtras(agora.subtract(const Duration(days: 2))),
          'há 2 d');
    });
  });

  group('DashboardSemana', () {
    test('soma totais de atual, anterior e planejado', () {
      final semana = DashboardSemana(
        inicio: DateTime(2026, 10, 4),
        fim: DateTime(2026, 10, 10),
        dias: [
          for (var i = 0; i < 7; i++)
            DashboardSemanaDia(
              data: DateTime(2026, 10, 4 + i),
              diaSemana: 'seg',
              label: '0$i',
              produzidoAtual: i,
              produzidoAnterior: 1,
              planejado: 2,
            ),
        ],
      );
      expect(semana.totalAtual, 0 + 1 + 2 + 3 + 4 + 5 + 6);
      expect(semana.totalAnterior, 7);
      expect(semana.totalPlanejado, 14);
    });
  });

  group('Capacidade', () {
    test('fromMap lê dia_semana e área', () {
      final c = CapacidadeFabrica.fromMap({
        'id': 'x',
        'area_produtiva_id': 'a1',
        'dia_semana': 1,
        'capacidade_diaria': 15,
        'ativa': true,
      });
      expect(c.diaSemana, 1);
      expect(c.areaId, 'a1');
      expect(c.capacidadeDiaria, 15);
    });

    test('CapacidadeDia.excedido', () {
      expect(
        CapacidadeDia(
          data: DateTime(2026, 10, 4),
          label: 'seg',
          capacidade: 10,
          planejado: 12,
        ).excedido,
        isTrue,
      );
      expect(
        CapacidadeDia(
          data: DateTime(2026, 10, 4),
          label: 'seg',
          capacidade: 0,
          planejado: 5,
        ).excedido,
        isFalse,
      );
    });
  });

  group('TutorialVideo.videoId', () {
    test('usa youtube_id quando presente', () {
      final v = TutorialVideo.fromMap({
        'id': '1',
        'titulo': 'Vídeo',
        'youtube_id': 'abcdefghijk',
        'youtube_url': 'https://youtu.be/zzzzzzzzzzz',
      });
      expect(v.videoId, 'abcdefghijk');
    });

    test('extrai da URL quando youtube_id ausente', () {
      final v = TutorialVideo.fromMap({
        'id': '1',
        'titulo': 'Vídeo',
        'youtube_url': 'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
      });
      expect(v.videoId, 'dQw4w9WgXcQ');
    });

    test('retorna null para URL inválida', () {
      final v = TutorialVideo.fromMap({
        'id': '1',
        'titulo': 'Vídeo',
        'youtube_url': 'https://exemplo.com/video',
      });
      expect(v.videoId, isNull);
    });
  });

  group('OrcamentoPdfService.resolveTexto', () {
    test('substitui variáveis conhecidas e mantém as desconhecidas', () {
      final out = OrcamentoPdfService.resolveTexto(
        'Cliente {{cliente}} — Total {{valor_total}} {{inexistente}}',
        {'cliente': 'ACME', 'valor_total': 'R\$ 1.000,00'},
      );
      expect(out, 'Cliente ACME — Total R\$ 1.000,00 {{inexistente}}');
    });
  });

  group('XlsxService.lerBytes (CSV)', () {
    test('faz parse de CSV com ; e aspas', () {
      final bytes = Uint8List.fromList(
        utf8.encode('Descrição;Valor\n"Aluguel, galpão";1500,00'),
      );
      final linhas = XlsxService.lerBytes(bytes, extensao: 'csv');
      expect(linhas.first, ['Descrição', 'Valor']);
      expect(linhas[1][0], 'Aluguel, galpão');
      expect(linhas[1][1], '1500,00');
    });
  });
}
