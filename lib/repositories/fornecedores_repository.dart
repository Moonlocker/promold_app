import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/offline/offline_database.dart';
import '../core/supabase/supabase_service.dart';
import '../models/fornecedor.dart';

/// Cadastro de fornecedores (tabela `fornecedores`).
class FornecedoresRepository {
  FornecedoresRepository({SupabaseClient? client})
      : _client = client ?? SupabaseService.client;

  final SupabaseClient _client;

  Future<List<Fornecedor>> list() async {
    final rows = await OfflineDatabase.instance.cachedRows(
      'cadastros:fornecedores',
      () async => List<Map<String, dynamic>>.from(
        await _client.from('fornecedores').select().order('razao_social'),
      ),
    );
    return rows.map((e) => Fornecedor.fromMap(e)).toList();
  }

  Future<void> create(Map<String, dynamic> data) async {
    await _client.from('fornecedores').insert(data);
  }

  Future<int> createMany(List<Map<String, dynamic>> rows) async {
    if (rows.isEmpty) return 0;
    await _client.from('fornecedores').insert(rows);
    return rows.length;
  }

  Future<void> update(String id, Map<String, dynamic> data) async {
    await _client.from('fornecedores').update(data).eq('id', id);
  }

  Future<void> delete(String id) async {
    await _client.from('fornecedores').delete().eq('id', id);
  }

  Future<void> toggleAtivo(String id, bool ativo) async {
    await _client.from('fornecedores').update({'ativo': ativo}).eq('id', id);
  }
}
