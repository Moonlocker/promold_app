import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/supabase/supabase_service.dart';
import '../models/obra_peca.dart';
import '../models/planejamento_semanal.dart';

/// Consultas de produção (Indicadores).
///
/// Espelha os hooks `useProducaoByDate` e `usePlanejamentoSemanal` do webapp.
class ProducaoRepository {
  ProducaoRepository({SupabaseClient? client})
    : _client = client ?? SupabaseService.client;

  final SupabaseClient _client;

  /// Peças concretadas (produção) no período, com o catálogo aninhado.
  ///
  /// Paginado para superar o limite de linhas do PostgREST.
  Future<List<ObraPeca>> listProducao(String inicio, String fim) async {
    const page = 1000;
    var from = 0;
    final all = <ObraPeca>[];
    while (true) {
      final rows = await _client
          .from('obras_pecas')
          .select('*, pecas_catalogo(*, categorias_peca(*))')
          .not('data_concretagem', 'is', null)
          .neq('status', 'pendente')
          .gte('data_concretagem', inicio)
          .lte('data_concretagem', fim)
          .order('data_concretagem', ascending: false)
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

  /// Planejamento semanal contido no período (mesma regra do webapp:
  /// `data_inicio >= inicio` e `data_fim <= fim`).
  Future<List<PlanejamentoSemanal>> listPlanejamento(
    String inicio,
    String fim, {
    String? tipo,
  }) async {
    var query = _client
        .from('planejamento_semanal')
        .select()
        .gte('data_inicio', inicio)
        .lte('data_fim', fim);
    if (tipo != null) query = query.eq('tipo', tipo);
    final rows = await query.order('data_inicio');
    return rows
        .map((e) => PlanejamentoSemanal.fromMap(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// Peças específicas (com catálogo) referenciadas por planejamentos, para
  /// calcular o volume/aço planejado sem carregar todas as peças da organização.
  Future<List<ObraPeca>> listPecasPorIds(List<String> ids) async {
    if (ids.isEmpty) return <ObraPeca>[];
    final rows = await _client
        .from('obras_pecas')
        .select('*, pecas_catalogo(*)')
        .inFilter('id', ids);
    return rows
        .map((e) => ObraPeca.fromMap(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// Planejamentos de um dia específico (para evitar duplicidade ao planejar).
  Future<List<PlanejamentoSemanal>> listPlanejamentoDia(
    String data,
    String tipo,
  ) async {
    final rows = await _client
        .from('planejamento_semanal')
        .select()
        .eq('data_inicio', data)
        .eq('data_fim', data)
        .eq('tipo', tipo);
    return rows
        .map((e) => PlanejamentoSemanal.fromMap(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// Cria um planejamento (uma peça em uma data).
  Future<void> criarPlanejamento({
    required String data,
    required String obraId,
    required String pecaCatalogoId,
    required String obraPecaId,
    required String tipo,
  }) async {
    await _client.from('planejamento_semanal').insert({
      'data_inicio': data,
      'data_fim': data,
      'obra_id': obraId,
      'peca_catalogo_id': pecaCatalogoId,
      'obra_peca_id': obraPecaId,
      'tipo': tipo,
    });
  }

  Future<void> removerPlanejamento(String id) async {
    await _client.from('planejamento_semanal').delete().eq('id', id);
  }

  /// Planejamento de montagem contido no período.
  Future<List<Map<String, dynamic>>> listMontagem(
    String inicio,
    String fim,
  ) async {
    final rows = await _client
        .from('planejamento_montagem')
        .select()
        .gte('data_inicio', inicio)
        .lte('data_fim', fim)
        .order('data_inicio');
    return rows.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Future<void> removerMontagem(String id) async {
    await _client.from('planejamento_montagem').delete().eq('id', id);
  }

  // ------------------------------------------------- Histórico / ocorrências
  Future<List<Map<String, dynamic>>> listPlanejamentoLogs({
    required String obraId,
    required String tipo,
  }) async {
    final rows = await _client
        .from('planejamento_logs')
        .select()
        .eq('obra_id', obraId)
        .eq('tipo_planejamento', tipo)
        .order('created_at', ascending: false)
        .limit(80);
    return rows.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Future<void> addPlanejamentoLog({
    required String tipo,
    required String obraId,
    String? dataReferencia,
    required String acao,
    String? descricao,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) return;
    final profile = await _client
        .from('profiles')
        .select('organizacao_id')
        .eq('user_id', user.id)
        .maybeSingle();
    final orgId = profile?['organizacao_id'] as String?;
    if (orgId == null) return;
    await _client.from('planejamento_logs').insert({
      'organizacao_id': orgId,
      'tipo_planejamento': tipo,
      'obra_id': obraId,
      'data_referencia': dataReferencia,
      'acao': acao,
      'descricao': descricao,
      'usuario_id': user.id,
    });
  }

  Future<void> deletePlanejamentoLog(String id) async {
    await _client.from('planejamento_logs').delete().eq('id', id);
  }
}
