import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/supabase/supabase_service.dart';
import '../models/categoria_peca.dart';
import '../models/obra.dart';
import '../models/obra_peca.dart';
import '../models/peca_catalogo.dart';

/// Acesso às obras, peças e catálogo. A RLS do Supabase limita tudo à
/// organização do usuário autenticado.
class ObrasRepository {
  ObrasRepository({SupabaseClient? client})
    : _client = client ?? SupabaseService.client;

  final SupabaseClient _client;

  // ---------------------------------------------------------------- Obras
  Future<List<Obra>> list() async {
    final rows = await _client
        .from('obras')
        .select()
        .order('prioridade', ascending: true);
    return rows.map((e) => Obra.fromMap(Map<String, dynamic>.from(e))).toList();
  }

  Future<Obra?> getById(String id) async {
    final row = await _client.from('obras').select().eq('id', id).maybeSingle();
    if (row == null) return null;
    return Obra.fromMap(Map<String, dynamic>.from(row));
  }

  Future<Obra> createObra(Map<String, dynamic> data) async {
    final row = await _client.from('obras').insert(data).select().single();
    return Obra.fromMap(Map<String, dynamic>.from(row));
  }

  Future<void> updateObra(String id, Map<String, dynamic> data) async {
    await _client.from('obras').update(data).eq('id', id);
  }

  Future<void> deleteObra(String id) async {
    await _client.from('obras').delete().eq('id', id);
  }

  // ---------------------------------------------------------------- Peças
  /// Lista todas as peças da obra (paginado para superar o limite do PostgREST).
  Future<List<ObraPeca>> listPecas(String obraId) async {
    const page = 1000;
    var from = 0;
    final all = <ObraPeca>[];
    while (true) {
      final rows = await _client
          .from('obras_pecas')
          .select('*, pecas_catalogo(*, categorias_peca(*))')
          .eq('obra_id', obraId)
          .range(from, from + page - 1);
      if (rows.isEmpty) break;
      all.addAll(
        rows.map((e) => ObraPeca.fromMap(Map<String, dynamic>.from(e))),
      );
      if (rows.length < page) break;
      from += page;
    }
    return all;
  }

  Future<void> createPecas(List<Map<String, dynamic>> rows) async {
    if (rows.isEmpty) return;
    await _client.from('obras_pecas').insert(rows);
  }

  /// Resumo leve de todas as peças (id, obra, status) para cálculo de progresso
  /// na listagem de obras.
  Future<List<ObraPeca>> listPecasResumo() async {
    const page = 1000;
    var from = 0;
    final all = <ObraPeca>[];
    while (true) {
      final rows = await _client
          .from('obras_pecas')
          .select('id, obra_id, status, peca_catalogo_id')
          .range(from, from + page - 1);
      if (rows.isEmpty) break;
      all.addAll(
        rows.map((e) => ObraPeca.fromMap(Map<String, dynamic>.from(e))),
      );
      if (rows.length < page) break;
      from += page;
    }
    return all;
  }

  Future<void> updatePeca(String id, Map<String, dynamic> data) async {
    await _client.from('obras_pecas').update(data).eq('id', id);
  }

  Future<void> deletePeca(String id) async {
    await _client.from('obras_pecas').delete().eq('id', id);
  }

  /// Posição de cada peça no mapa de montagem (`mapa_montagem_celulas`),
  /// no formato `<footer><coluna+1>-<linha+1>` (ex.: `V3-2`).
  Future<Map<String, String>> listPosicoes(String obraId) async {
    final rows = await _client
        .from('mapa_montagem_celulas')
        .select(
          'obra_peca_id, coluna, linha, status, mapa_montagem_vistas(descricao)',
        )
        .eq('obra_id', obraId);
    final map = <String, String>{};
    final regex = RegExp(r'^\{FOOTER:([^}]*)\}');
    for (final row in rows) {
      final map2 = Map<String, dynamic>.from(row);
      if (map2['status'] == 'excluida') continue;
      final pecaId = map2['obra_peca_id'] as String?;
      if (pecaId == null) continue;
      final vista = map2['mapa_montagem_vistas'];
      final descricao = vista is Map
          ? (vista['descricao'] as String?) ?? ''
          : '';
      final match = regex.firstMatch(descricao);
      final footer = match != null ? match.group(1) ?? 'V' : 'V';
      final coluna = (map2['coluna'] as num?)?.toInt() ?? 0;
      final linha = (map2['linha'] as num?)?.toInt() ?? 0;
      map[pecaId] = '$footer${coluna + 1}-${linha + 1}';
    }
    return map;
  }

  // -------------------------------------------------------------- Catálogo
  Future<List<PecaCatalogo>> listPecasCatalogo() async {
    final rows = await _client
        .from('pecas_catalogo')
        .select('*, categorias_peca(*)')
        .order('nome');
    return rows
        .map((e) => PecaCatalogo.fromMap(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<List<CategoriaPeca>> listCategoriasPeca() async {
    final rows = await _client.from('categorias_peca').select().order('nome');
    return rows
        .map((e) => CategoriaPeca.fromMap(Map<String, dynamic>.from(e)))
        .toList();
  }
}
