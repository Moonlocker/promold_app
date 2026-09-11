import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/supabase/supabase_service.dart';
import '../models/categoria_peca.dart';
import '../models/peca_catalogo.dart';

/// Catálogo de peças e suas categorias (tabelas `pecas_catalogo` e
/// `categorias_peca`).
class PecasCatalogoRepository {
  PecasCatalogoRepository({SupabaseClient? client})
      : _client = client ?? SupabaseService.client;

  final SupabaseClient _client;

  // ------------------------------------------------------------------- Peças
  Future<List<PecaCatalogo>> list() async {
    final rows = await _client
        .from('pecas_catalogo')
        .select('*, categorias_peca(*)')
        .order('nome');
    return rows
        .map((e) => PecaCatalogo.fromMap(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<void> create(Map<String, dynamic> data) async {
    await _client.from('pecas_catalogo').insert(data);
  }

  Future<void> update(String id, Map<String, dynamic> data) async {
    await _client.from('pecas_catalogo').update(data).eq('id', id);
  }

  Future<void> toggleAtiva(String id, bool ativa) async {
    await _client.from('pecas_catalogo').update({'ativa': ativa}).eq('id', id);
  }

  Future<void> delete(String id) async {
    await _client.from('pecas_catalogo').delete().eq('id', id);
  }

  /// Renomeia o identificador de todas as peças de obra vinculadas à peça de
  /// catálogo (mesma regra do webapp ao alterar o identificador padrão).
  Future<int> propagarIdentificador({
    required String pecaCatalogoId,
    required String identificadorAntigo,
    required String identificadorNovo,
  }) async {
    final rows = await _client
        .from('obras_pecas')
        .select('id, identificador')
        .eq('peca_catalogo_id', pecaCatalogoId);
    var updated = 0;
    for (final row in rows) {
      final atual = row['identificador'] as String?;
      if (atual != null && atual.startsWith(identificadorAntigo)) {
        final sufixo = atual.substring(identificadorAntigo.length);
        await _client
            .from('obras_pecas')
            .update({'identificador': '$identificadorNovo$sufixo'}).eq(
                  'id',
                  row['id'] as String,
                );
        updated++;
      }
    }
    return updated;
  }

  // -------------------------------------------------------------- Categorias
  Future<List<CategoriaPeca>> listCategorias() async {
    final rows = await _client.from('categorias_peca').select().order('nome');
    return rows
        .map((e) => CategoriaPeca.fromMap(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<CategoriaPeca> createCategoria(Map<String, dynamic> data) async {
    final row =
        await _client.from('categorias_peca').insert(data).select().single();
    return CategoriaPeca.fromMap(Map<String, dynamic>.from(row));
  }

  Future<void> updateCategoria(String id, Map<String, dynamic> data) async {
    await _client.from('categorias_peca').update(data).eq('id', id);
  }

  Future<void> deleteCategoria(String id) async {
    await _client.from('categorias_peca').delete().eq('id', id);
  }
}
