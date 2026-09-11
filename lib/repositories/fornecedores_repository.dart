import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/supabase/supabase_service.dart';
import '../models/fornecedor.dart';

/// Cadastro de fornecedores (tabela `fornecedores`).
class FornecedoresRepository {
  FornecedoresRepository({SupabaseClient? client})
      : _client = client ?? SupabaseService.client;

  final SupabaseClient _client;

  Future<List<Fornecedor>> list() async {
    final rows = await _client.from('fornecedores').select().order('razao_social');
    return rows
        .map((e) => Fornecedor.fromMap(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<void> create(Map<String, dynamic> data) async {
    await _client.from('fornecedores').insert(data);
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
