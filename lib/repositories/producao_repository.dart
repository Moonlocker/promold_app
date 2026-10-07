import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/offline/offline_database.dart';
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
    final rows = await OfflineDatabase.instance.cachedRows(
      'producao:$inicio:$fim',
      () async {
        const page = 1000;
        var from = 0;
        final all = <Map<String, dynamic>>[];
        while (true) {
          final data = await _client
              .from('obras_pecas')
              .select('*, pecas_catalogo(*, categorias_peca(*))')
              .not('data_concretagem', 'is', null)
              .neq('status', 'pendente')
              .gte('data_concretagem', inicio)
              .lte('data_concretagem', fim)
              .order('data_concretagem', ascending: false)
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

  /// Planejamento semanal contido no período (mesma regra do webapp:
  /// `data_inicio >= inicio` e `data_fim <= fim`).
  Future<List<PlanejamentoSemanal>> listPlanejamento(
    String inicio,
    String fim, {
    String? tipo,
  }) async {
    final rows = await OfflineDatabase.instance.cachedRows(
      'planejamento:$tipo:$inicio:$fim',
      () async {
        var query = _client
            .from('planejamento_semanal')
            .select()
            .gte('data_inicio', inicio)
            .lte('data_fim', fim);
        if (tipo != null) query = query.eq('tipo', tipo);
        final data = await query.order('data_inicio');
        return data.map((e) => Map<String, dynamic>.from(e)).toList();
      },
    );
    return rows.map((e) => PlanejamentoSemanal.fromMap(e)).toList();
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
    final rows = await OfflineDatabase.instance.cachedRows(
      'planejamento_dia:$tipo:$data',
      () async => List<Map<String, dynamic>>.from(
        await _client
            .from('planejamento_semanal')
            .select()
            .eq('data_inicio', data)
            .eq('data_fim', data)
            .eq('tipo', tipo),
      ),
    );
    return rows.map((e) => PlanejamentoSemanal.fromMap(e)).toList();
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

  /// Reagenda um planejamento (uma peça) para outra data.
  /// Se a peça já estiver planejada nesse dia, remove o registro de origem.
  Future<void> reagendarPlanejamento(String planId, String data) async {
    final atual = await _client
        .from('planejamento_semanal')
        .select('obra_peca_id, tipo')
        .eq('id', planId)
        .maybeSingle();
    final pecaId = atual?['obra_peca_id'] as String?;
    final tipo = atual?['tipo'] as String?;
    if (pecaId != null && tipo != null) {
      final existente = await _client
          .from('planejamento_semanal')
          .select('id')
          .eq('obra_peca_id', pecaId)
          .eq('data_inicio', data)
          .eq('tipo', tipo)
          .neq('id', planId)
          .maybeSingle();
      if (existente != null) {
        await _client.from('planejamento_semanal').delete().eq('id', planId);
        return;
      }
    }
    await _client
        .from('planejamento_semanal')
        .update({'data_inicio': data, 'data_fim': data})
        .eq('id', planId);
  }

  /// Replica um planejamento para outra data, mantendo o original.
  /// Ignora se a peça já estiver planejada nesse dia.
  Future<void> duplicarPlanejamento(String planId, String data) async {
    final row = await _client
        .from('planejamento_semanal')
        .select()
        .eq('id', planId)
        .single();
    final pecaId = row['obra_peca_id'] as String?;
    final tipo = row['tipo'] as String?;
    if (pecaId != null && tipo != null) {
      final existente = await _client
          .from('planejamento_semanal')
          .select('id')
          .eq('obra_peca_id', pecaId)
          .eq('data_inicio', data)
          .eq('tipo', tipo)
          .maybeSingle();
      if (existente != null) return;
    }
    final novo = Map<String, dynamic>.from(row)
      ..remove('id')
      ..remove('created_at')
      ..remove('updated_at')
      ..['data_inicio'] = data
      ..['data_fim'] = data;
    await _client.from('planejamento_semanal').insert(novo);
  }

  /// Move todos os planejamentos de uma obra de um dia para outro.
  ///
  /// Duplicatas (mesma peça já planejada no dia de destino) são removidas da
  /// origem. Retorna a quantidade de planejamentos efetivamente movidos.
  Future<int> moverObraDia({
    required String obraId,
    required String fromDate,
    required String toDate,
    required String tipo,
  }) async {
    if (obraId.isEmpty || fromDate == toDate) return 0;
    final source = await _client
        .from('planejamento_semanal')
        .select('id, obra_peca_id')
        .eq('obra_id', obraId)
        .eq('data_inicio', fromDate)
        .eq('tipo', tipo);
    if (source.isEmpty) return 0;
    final target = await _client
        .from('planejamento_semanal')
        .select('obra_peca_id')
        .eq('obra_id', obraId)
        .eq('data_inicio', toDate)
        .eq('tipo', tipo);
    final targetIds = target
        .map((e) => e['obra_peca_id'])
        .whereType<String>()
        .toSet();

    final paraRemover = <String>[];
    final paraMover = <String>[];
    for (final p in source) {
      final pecaId = p['obra_peca_id'] as String?;
      final id = p['id'] as String;
      if (pecaId != null && targetIds.contains(pecaId)) {
        paraRemover.add(id);
      } else {
        paraMover.add(id);
      }
    }
    if (paraRemover.isNotEmpty) {
      await _client
          .from('planejamento_semanal')
          .delete()
          .inFilter('id', paraRemover);
    }
    if (paraMover.isNotEmpty) {
      await _client.from('planejamento_semanal').update({
        'data_inicio': toDate,
        'data_fim': toDate,
      }).inFilter('id', paraMover);
    }
    return paraMover.length;
  }

  /// Remove todos os planejamentos do tipo no período. Retorna o total removido.
  Future<int> limparPeriodo(
    String inicio,
    String fim,
    String tipo,
  ) async {
    final rows = await _client
        .from('planejamento_semanal')
        .select('id')
        .gte('data_inicio', inicio)
        .lte('data_inicio', fim)
        .eq('tipo', tipo);
    final ids = rows.map((e) => e['id'] as String).toList();
    if (ids.isNotEmpty) {
      await _client
          .from('planejamento_semanal')
          .delete()
          .inFilter('id', ids);
    }
    return ids.length;
  }

  /// Planejamento de montagem contido no período.
  Future<List<Map<String, dynamic>>> listMontagem(
    String inicio,
    String fim,
  ) async {
    return OfflineDatabase.instance.cachedRows(
      'montagem:$inicio:$fim',
      () async => List<Map<String, dynamic>>.from(
        await _client
            .from('planejamento_montagem')
            .select()
            .gte('data_inicio', inicio)
            .lte('data_fim', fim)
            .order('data_inicio'),
      ),
    );
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
