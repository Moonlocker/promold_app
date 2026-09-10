import 'package:flutter_test/flutter_test.dart';
import 'package:promold_app/models/estoque.dart';

void main() {
  group('Estoque', () {
    test('extrai imagem e descrição limpa de [IMG:url]', () {
      final e = Estoque.fromMap({
        'id': 'e1',
        'nome': 'Pátio A',
        'descricao': '[IMG:https://x/y.jpg] Área externa',
        'capacidade': 100,
      });
      expect(e.imagemUrl, 'https://x/y.jpg');
      expect(e.descricaoLimpa, 'Área externa');
      expect(e.capacidade, 100);
      expect(e.isSistema, isFalse);
    });

    test('sem imagem retorna null', () {
      final e = Estoque.fromMap({'id': 'e2', 'nome': 'Galpão'});
      expect(e.imagemUrl, isNull);
      expect(e.descricaoLimpa, '');
    });

    test('permiteTodas quando sem restrições', () {
      final e = Estoque.fromMap({'id': 'e3', 'nome': 'X'});
      expect(e.permiteTodas, isTrue);
    });

    test('reconhece estoque de sistema', () {
      final e = Estoque.fromMap({
        'id': 'e4',
        'nome': Estoque.nomeSistema,
      });
      expect(e.isSistema, isTrue);
    });
  });

  group('PecaEmEstoque', () {
    test('resolve nome da obra e da peça', () {
      final p = PecaEmEstoque.fromMap({
        'id': 'p1',
        'obra_id': 'o1',
        'identificador': 'V-01',
        'estoque_id': 'e1',
        'pecas_catalogo': {'nome': 'Viga', 'categoria_id': 'c1'},
        'obras': {'nome': 'Obra X', 'cor': '#3B82F6'},
      });
      expect(p.pecaNome, 'Viga');
      expect(p.obraNome, 'Obra X');
      expect(p.obraCor, '#3B82F6');
      expect(p.identificador, 'V-01');
    });
  });
}
