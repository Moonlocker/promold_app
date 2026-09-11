import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/supabase/supabase_service.dart';

/// Orçamento — estrutura avançada: etapas → composições → insumos.
class OrcamentoComposicoesRepository {
  OrcamentoComposicoesRepository({SupabaseClient? client})
      : _client = client ?? SupabaseService.client;

  final SupabaseClient _client;

  // ------------------------------------------------------------------ Etapas
  Future<List<Map<String, dynamic>>> listEtapas(String orcamentoId) async {
    final rows = await _client
        .from('orcamentos_etapas')
        .select()
        .eq('orcamento_id', orcamentoId)
        .order('ordem');
    return rows.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Future<void> createEtapa(String orcamentoId, String nome, int ordem) async {
    await _client.from('orcamentos_etapas').insert({
      'orcamento_id': orcamentoId,
      'nome': nome,
      'ordem': ordem,
    });
  }

  Future<void> renameEtapa(String id, String nome) async {
    await _client.from('orcamentos_etapas').update({'nome': nome}).eq('id', id);
  }

  Future<void> deleteEtapa(String id) async {
    final composicoes = await _client
        .from('orcamentos_composicoes')
        .select('id')
        .eq('etapa_id', id);
    final ids = composicoes.map((c) => c['id'] as String).toList();
    if (ids.isNotEmpty) {
      await _client
          .from('orcamentos_composicoes_insumos')
          .delete()
          .inFilter('orcamento_composicao_id', ids);
      await _client.from('orcamentos_composicoes').delete().inFilter('id', ids);
    }
    await _client.from('orcamentos_etapas').delete().eq('id', id);
  }

  // ------------------------------------------------------------- Composições
  Future<List<Map<String, dynamic>>> listComposicoes(String etapaId) async {
    final rows = await _client
        .from('orcamentos_composicoes')
        .select('*, composicoes(nome, unidade)')
        .eq('etapa_id', etapaId)
        .order('ordem');
    return rows.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Future<List<Map<String, dynamic>>> listComposicaoInsumos(
    String orcamentoComposicaoId,
  ) async {
    final rows = await _client
        .from('orcamentos_composicoes_insumos')
        .select()
        .eq('orcamento_composicao_id', orcamentoComposicaoId)
        .order('created_at');
    return rows.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  /// Catálogo de composições (templates).
  Future<List<Map<String, dynamic>>> listCatalogo() async {
    final rows = await _client
        .from('composicoes')
        .select('id, nome, unidade, peca_catalogo_id, custo_total')
        .order('nome');
    return rows.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  /// Insumos de uma composição do catálogo (com nome/unidade/preço).
  Future<List<Map<String, dynamic>>> listCatalogoInsumos(
    String composicaoId,
  ) async {
    final rows = await _client
        .from('composicoes_insumos')
        .select('id, quantidade, insumo_id, insumos(nome, unidade, preco)')
        .eq('composicao_id', composicaoId);
    return rows.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  /// Catálogo de insumos.
  Future<List<Map<String, dynamic>>> listInsumos() async {
    final rows = await _client
        .from('insumos')
        .select('id, nome, unidade, preco, tipo, parametro_vinculado')
        .order('nome');
    return rows.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  /// Adiciona uma composição do catálogo a uma etapa, copiando seus insumos
  /// como snapshot. Retorna o id da composição do orçamento.
  Future<String> addComposicaoFromCatalogo({
    required String etapaId,
    required String composicaoId,
    required int ordem,
    double quantidade = 1,
  }) async {
    final comp = await _client
        .from('composicoes')
        .select('id, nome, unidade, peca_catalogo_id')
        .eq('id', composicaoId)
        .single();
    final row = await _client
        .from('orcamentos_composicoes')
        .insert({
          'etapa_id': etapaId,
          'composicao_id': composicaoId,
          'nome': comp['nome'],
          'peca_catalogo_id': comp['peca_catalogo_id'],
          'quantidade': quantidade,
          'ordem': ordem,
        })
        .select('id')
        .single();
    final orcCompId = row['id'] as String;

    final insumos = await _client
        .from('composicoes_insumos')
        .select('quantidade, insumo_id, insumos(nome, unidade, preco)')
        .eq('composicao_id', composicaoId);
    final rows = insumos.map((e) {
      final ins = e['insumos'];
      final nome = ins is Map ? (ins['nome'] as String? ?? '') : '';
      final unidade = ins is Map ? ins['unidade'] as String? : null;
      final preco = ins is Map ? ((ins['preco'] as num?)?.toDouble() ?? 0) : 0.0;
      final qtd = (e['quantidade'] as num?)?.toDouble() ?? 0;
      return {
        'orcamento_composicao_id': orcCompId,
        'insumo_id': e['insumo_id'],
        'nome_insumo': nome,
        'unidade_insumo': unidade,
        'preco_unitario': preco,
        'quantidade': qtd,
        'custo_total': qtd * preco,
      };
    }).toList();
    if (rows.isNotEmpty) {
      await _client.from('orcamentos_composicoes_insumos').insert(rows);
    }
    await _recalcular(orcCompId);
    return orcCompId;
  }

  Future<void> updateComposicao(String id, Map<String, dynamic> data) async {
    await _client.from('orcamentos_composicoes').update(data).eq('id', id);
    await _recalcular(id);
  }

  Future<void> deleteComposicao(String id) async {
    await _client
        .from('orcamentos_composicoes_insumos')
        .delete()
        .eq('orcamento_composicao_id', id);
    await _client.from('orcamentos_composicoes').delete().eq('id', id);
  }

  Future<void> addInsumo(
    String orcamentoComposicaoId,
    Map<String, dynamic> data,
  ) async {
    await _client.from('orcamentos_composicoes_insumos').insert({
      'orcamento_composicao_id': orcamentoComposicaoId,
      ...data,
    });
    await _recalcular(orcamentoComposicaoId);
  }

  Future<void> updateInsumo(String id, Map<String, dynamic> data) async {
    final row = await _client
        .from('orcamentos_composicoes_insumos')
        .update(data)
        .eq('id', id)
        .select('orcamento_composicao_id')
        .single();
    await _recalcular(row['orcamento_composicao_id'] as String);
  }

  Future<void> deleteInsumo(String id) async {
    final row = await _client
        .from('orcamentos_composicoes_insumos')
        .select('orcamento_composicao_id')
        .eq('id', id)
        .maybeSingle();
    await _client.from('orcamentos_composicoes_insumos').delete().eq('id', id);
    if (row != null) {
      await _recalcular(row['orcamento_composicao_id'] as String);
    }
  }

  /// Recalcula o custo total da composição (soma dos insumos).
  Future<void> _recalcular(String orcamentoComposicaoId) async {
    final insumos = await listComposicaoInsumos(orcamentoComposicaoId);
    final total = insumos.fold<double>(
      0,
      (a, i) =>
          a +
          ((i['custo_total'] as num?)?.toDouble() ??
              ((i['quantidade'] as num?)?.toDouble() ?? 0) *
                  ((i['preco_unitario'] as num?)?.toDouble() ?? 0)),
    );
    await _client
        .from('orcamentos_composicoes')
        .update({'custo_total': total})
        .eq('id', orcamentoComposicaoId);
  }

  /// Soma dos custos de todas as composições do orçamento.
  Future<double> totalOrcamento(String orcamentoId) async {
    final etapas = await listEtapas(orcamentoId);
    var total = 0.0;
    for (final e in etapas) {
      final comps = await listComposicoes(e['id'] as String);
      total += comps.fold<double>(
        0,
        (a, c) => a + ((c['custo_total'] as num?)?.toDouble() ?? 0),
      );
    }
    return total;
  }
}
