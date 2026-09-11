import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/supabase/supabase_service.dart';
import '../models/cliente.dart';

/// Cadastro de clientes (tabela `clientes`).
class ClientesRepository {
  ClientesRepository({SupabaseClient? client})
      : _client = client ?? SupabaseService.client;

  final SupabaseClient _client;

  Future<List<Cliente>> list() async {
    final rows = await _client.from('clientes').select().order('nome');
    return rows.map((e) => Cliente.fromMap(Map<String, dynamic>.from(e))).toList();
  }

  Future<void> create(Map<String, dynamic> data) async {
    await _client.from('clientes').insert(data);
  }

  Future<void> update(String id, Map<String, dynamic> data) async {
    await _client.from('clientes').update(data).eq('id', id);
  }

  Future<void> delete(String id) async {
    await _client.from('clientes').delete().eq('id', id);
  }
}
