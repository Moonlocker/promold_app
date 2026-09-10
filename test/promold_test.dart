import 'package:flutter_test/flutter_test.dart';
import 'package:promold_app/core/utils/formatters.dart';
import 'package:promold_app/models/obra.dart';

void main() {
  group('Formatters', () {
    test('hojeBr retorna data no formato ISO yyyy-MM-dd', () {
      expect(RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(Formatters.hojeBr()),
          isTrue);
    });

    test('semanaAtualBr retorna início e fim válidos', () {
      final (inicio, fim) = Formatters.semanaAtualBr();
      expect(inicio.compareTo(fim), lessThan(0));
    });

    test('moeda formata valores em Real', () {
      expect(Formatters.moeda(1234.5), 'R\$ 1.234,50');
    });
  });

  group('Obra', () {
    test('fromMap converte campos snake_case', () {
      final obra = Obra.fromMap({
        'id': 'abc',
        'nome': 'Obra Teste',
        'cliente': 'Cliente X',
        'status': 'ativa',
        'prioridade': 2,
        'data_inicio': '2026-01-10',
      });
      expect(obra.id, 'abc');
      expect(obra.nome, 'Obra Teste');
      expect(obra.cliente, 'Cliente X');
      expect(obra.ativa, isTrue);
      expect(obra.prioridade, 2);
      expect(obra.dataInicio, DateTime(2026, 1, 10));
    });

    test('ativa é falso para status diferente de ativa', () {
      final obra = Obra.fromMap({
        'id': '1',
        'nome': 'O',
        'cliente': 'C',
        'status': 'pausada',
      });
      expect(obra.ativa, isFalse);
    });
  });
}
