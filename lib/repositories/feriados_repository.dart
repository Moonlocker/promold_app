import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/supabase/supabase_service.dart';
import '../models/feriado.dart';

/// Feriados da organização (usados no planejamento).
class FeriadosRepository {
  FeriadosRepository({SupabaseClient? client})
      : _client = client ?? SupabaseService.client;

  final SupabaseClient _client;

  static const _nacionaisFixos = [
    ('Confraternização Universal', '01-01'),
    ('Tiradentes', '04-21'),
    ('Dia do Trabalho', '05-01'),
    ('Independência do Brasil', '09-07'),
    ('Nossa Senhora Aparecida', '10-12'),
    ('Finados', '11-02'),
    ('Proclamação da República', '11-15'),
    ('Natal', '12-25'),
  ];

  Future<List<Feriado>> list() async {
    final rows =
        await _client.from('feriados').select().order('data');
    return rows
        .map((e) => Feriado.fromMap(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<void> create(Map<String, dynamic> data) async {
    await _client.from('feriados').insert(data);
  }

  Future<void> delete(String id) async {
    await _client.from('feriados').delete().eq('id', id);
  }

  /// Importa os feriados nacionais fixos ainda não cadastrados.
  /// Retorna quantos foram inseridos.
  Future<int> importarNacionaisFixos(List<Feriado> existentes) async {
    final md = existentes
        .where((f) => f.recorrente && f.data.length >= 5)
        .map((f) => f.data.substring(5))
        .toSet();
    final novos = _nacionaisFixos
        .where((f) => !md.contains(f.$2))
        .map((f) => {
              'nome': f.$1,
              'data': '2000-${f.$2}',
              'tipo': 'nacional_fixo',
              'recorrente': true,
            })
        .toList();
    if (novos.isEmpty) return 0;
    await _client.from('feriados').insert(novos);
    return novos.length;
  }
}
