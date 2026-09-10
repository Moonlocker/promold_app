import 'package:flutter_test/flutter_test.dart';
import 'package:promold_app/models/leitor.dart';

void main() {
  group('PecaLeitor', () {
    test('resolve nome da peça, obra e data de referência', () {
      final p = PecaLeitor.fromMap({
        'id': 'p1',
        'identificador': 'V-01',
        'status': 'concretada',
        'data_armacao': '2026-01-10',
        'pecas_catalogo': {'nome': 'Viga'},
        'obras': {'nome': 'Obra X'},
      }, 'data_armacao');
      expect(p.identificador, 'V-01');
      expect(p.status, 'concretada');
      expect(p.pecaNome, 'Viga');
      expect(p.obraNome, 'Obra X');
      expect(p.dataReferencia, DateTime(2026, 1, 10));
    });
  });

  group('PecaConsulta', () {
    test('resolve obra, catálogo, posição e lote', () {
      final p = PecaConsulta.fromMap({
        'id': 'p1',
        'obra_id': 'o1',
        'identificador': 'V-01',
        'status': 'em_estoque',
        'obra': {'id': 'o1', 'nome': 'Obra X', 'cor': '#3B82F6'},
        'catalogo': {
          'nome': 'Viga',
          'tipo_calculo': 'linear',
          'categoria': {'nome': 'Estrutura'},
        },
        'posicao': [
          {
            'coluna': 2,
            'linha': 1,
            'vista': {'descricao': '{FOOTER:B} Vista 1'},
          }
        ],
        'lote': {
          'id': 'l1',
          'codigo': 'LOTE-1',
          'fck_mpa': 30,
          'volume_m3': 5.5,
        },
        'comprimento': 6,
      });
      expect(p.obraNome, 'Obra X');
      expect(p.catalogoNome, 'Viga');
      expect(p.categoriaNome, 'Estrutura');
      expect(p.posicao, 'B3-2');
      expect(p.lote?.codigo, 'LOTE-1');
      expect(p.lote?.fckMpa, 30);
      expect(p.comprimento, 6);
    });

    test('sem posição e sem lote', () {
      final p = PecaConsulta.fromMap({
        'id': 'p2',
        'obra_id': 'o1',
        'identificador': 'X',
        'status': 'pendente',
      });
      expect(p.posicao, isNull);
      expect(p.lote, isNull);
      expect(p.tipoCalculo, 'linear');
    });
  });
}
