import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/supabase/supabase_service.dart';
import '../models/categoria_financeira.dart';
import '../models/centro_custo.dart';

/// Cadastros base do financeiro: centros de custo e categorias.
class FinanceiroCadastrosRepository {
  FinanceiroCadastrosRepository({SupabaseClient? client})
      : _client = client ?? SupabaseService.client;

  final SupabaseClient _client;

  // --------------------------------------------------------- Centros de custo
  Future<List<CentroCusto>> listCentros() async {
    final rows = await _client.from('centros_custo').select().order('nome');
    return rows
        .map((e) => CentroCusto.fromMap(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<void> createCentro(Map<String, dynamic> data) async {
    await _client.from('centros_custo').insert(data);
  }

  Future<void> updateCentro(String id, Map<String, dynamic> data) async {
    await _client.from('centros_custo').update(data).eq('id', id);
  }

  Future<void> deleteCentro(String id) async {
    await _client.from('centros_custo').delete().eq('id', id);
  }

  Future<int> countUsoCentro(String id) async {
    final pagar = await _client
        .from('contas_pagar')
        .select('id')
        .eq('centro_custo_id', id)
        .count(CountOption.exact);
    final receber = await _client
        .from('contas_receber')
        .select('id')
        .eq('centro_custo_id', id)
        .count(CountOption.exact);
    return pagar.count + receber.count;
  }

  // ------------------------------------------------------------ Categorias
  Future<List<CategoriaFinanceira>> listCategorias() async {
    final rows = await _client.from('categorias_financeiras').select().order('nome');
    return rows
        .map((e) => CategoriaFinanceira.fromMap(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<void> createCategoria(Map<String, dynamic> data) async {
    await _client.from('categorias_financeiras').insert(data);
  }

  Future<void> updateCategoria(String id, Map<String, dynamic> data) async {
    await _client.from('categorias_financeiras').update(data).eq('id', id);
  }

  Future<void> deleteCategoria(String id) async {
    await _client.from('categorias_financeiras').delete().eq('id', id);
  }

  Future<int> countUsoCategoria(String id) async {
    final pagar = await _client
        .from('contas_pagar')
        .select('id')
        .eq('categoria_id', id)
        .count(CountOption.exact);
    final receber = await _client
        .from('contas_receber')
        .select('id')
        .eq('categoria_id', id)
        .count(CountOption.exact);
    return pagar.count + receber.count;
  }
}
