import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/offline/offline_database.dart';
import '../core/supabase/supabase_service.dart';
import '../models/categoria_peca.dart';
import '../models/obra.dart';
import '../models/obra_peca.dart';
import '../models/peca_catalogo.dart';

/// Acesso às obras, peças e catálogo. A RLS do Supabase limita tudo à
/// organização do usuário autenticado.
///
/// As leituras são cache-first: quando o aparelho está offline, o último
/// resultado é servido do banco local (ver `OfflineDatabase`).
class ObrasRepository {
  ObrasRepository({SupabaseClient? client})
    : _client = client ?? SupabaseService.client;

  final SupabaseClient _client;

  // ---------------------------------------------------------------- Obras
  Future<List<Obra>> list() async {
    final rows = await OfflineDatabase.instance.cachedRows(
      'obras:list',
      () async => List<Map<String, dynamic>>.from(
        await _client.from('obras').select().order(
              'prioridade',
              ascending: true,
            ),
      ),
    );
    return rows.map((e) => Obra.fromMap(e)).toList();
  }

  Future<Obra?> getById(String id) async {
    final row = await OfflineDatabase.instance.cachedRow(
      'obras:$id',
      () async {
        final data =
            await _client.from('obras').select().eq('id', id).maybeSingle();
        return data == null ? null : Map<String, dynamic>.from(data);
      },
    );
    if (row == null) return null;
    return Obra.fromMap(row);
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
    final rows = await OfflineDatabase.instance.cachedRows(
      'obras:pecas:$obraId',
      () => _fetchPecas(
        obraId,
        '*, pecas_catalogo(*, categorias_peca(*))',
      ),
    );
    return rows.map((e) => ObraPeca.fromMap(e)).toList();
  }

  /// Busca paginada de peças, agregando todas as páginas em uma lista de mapas.
  Future<List<Map<String, dynamic>>> _fetchPecas(
    String obraId,
    String select,
  ) async {
    const page = 1000;
    var from = 0;
    final all = <Map<String, dynamic>>[];
    while (true) {
      final rows = await _client
          .from('obras_pecas')
          .select(select)
          .eq('obra_id', obraId)
          .range(from, from + page - 1);
      if (rows.isEmpty) break;
      all.addAll(rows.map((e) => Map<String, dynamic>.from(e)));
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
    final rows = await OfflineDatabase.instance.cachedRows(
      'obras:pecas_resumo',
      () async {
        const page = 1000;
        var from = 0;
        final all = <Map<String, dynamic>>[];
        while (true) {
          final data = await _client
              .from('obras_pecas')
              .select('id, obra_id, status, peca_catalogo_id')
              .range(from, from + page - 1);
          if (data.isEmpty) break;
          all.addAll(data.map((e) => Map<String, dynamic>.from(e)));
          if (data.length < page) break;
          from += page;
        }
        return all;
      },
    );
    return rows.map((e) => ObraPeca.fromMap(e)).toList();
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
    final rows = await OfflineDatabase.instance.cachedRows(
      'obras:posicoes:$obraId',
      () async => List<Map<String, dynamic>>.from(
        await _client
            .from('mapa_montagem_celulas')
            .select(
              'obra_peca_id, coluna, linha, status, mapa_montagem_vistas(descricao)',
            )
            .eq('obra_id', obraId),
      ),
    );
    final map = <String, String>{};
    final regex = RegExp(r'^\{FOOTER:([^}]*)\}');
    for (final row in rows) {
      if (row['status'] == 'excluida') continue;
      final pecaId = row['obra_peca_id'] as String?;
      if (pecaId == null) continue;
      final vista = row['mapa_montagem_vistas'];
      final descricao =
          vista is Map ? (vista['descricao'] as String?) ?? '' : '';
      final match = regex.firstMatch(descricao);
      final footer = match != null ? match.group(1) ?? 'V' : 'V';
      final coluna = (row['coluna'] as num?)?.toInt() ?? 0;
      final linha = (row['linha'] as num?)?.toInt() ?? 0;
      map[pecaId] = '$footer${coluna + 1}-${linha + 1}';
    }
    return map;
  }

  // -------------------------------------------------------------- Catálogo
  Future<List<PecaCatalogo>> listPecasCatalogo() async {
    final rows = await OfflineDatabase.instance.cachedRows(
      'catalogo:pecas',
      () async => List<Map<String, dynamic>>.from(
        await _client
            .from('pecas_catalogo')
            .select('*, categorias_peca(*)')
            .order('nome'),
      ),
    );
    return rows.map((e) => PecaCatalogo.fromMap(e)).toList();
  }

  Future<List<CategoriaPeca>> listCategoriasPeca() async {
    final rows = await OfflineDatabase.instance.cachedRows(
      'catalogo:categorias',
      () async => List<Map<String, dynamic>>.from(
        await _client.from('categorias_peca').select().order('nome'),
      ),
    );
    return rows.map((e) => CategoriaPeca.fromMap(e)).toList();
  }
}
