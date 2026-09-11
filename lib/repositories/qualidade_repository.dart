import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/logic/qc_engine.dart';
import '../core/supabase/supabase_service.dart';
import '../models/qc.dart';

/// Módulo Qualidade: lotes de concreto, corpos de prova, ensaios e padrões.
class QualidadeRepository {
  QualidadeRepository({SupabaseClient? client})
      : _client = client ?? SupabaseService.client;

  final SupabaseClient _client;

  // ------------------------------------------------------------------- Lotes
  Future<List<QcLote>> listLotes() async {
    final rows = await _client
        .from('qc_lotes_concreto')
        .select()
        .order('data_concretagem', ascending: false);
    return rows.map((e) => QcLote.fromMap(Map<String, dynamic>.from(e))).toList();
  }

  Future<String> saveLote(Map<String, dynamic> data, {String? id}) async {
    if (id != null) {
      await _client.from('qc_lotes_concreto').update(data).eq('id', id);
      return id;
    }
    final row = await _client
        .from('qc_lotes_concreto')
        .insert(data)
        .select('id')
        .single();
    return row['id'] as String;
  }

  Future<void> deleteLote(String id) async {
    await _client.from('qc_lotes_concreto').delete().eq('id', id);
  }

  // --------------------------------------------------------- Corpos de prova
  Future<List<QcCorpoProva>> listCps({String? loteId}) async {
    final query = _client.from('qc_corpos_prova').select();
    final rows = loteId == null
        ? await query.order('data_moldagem', ascending: false)
        : await query
            .eq('lote_id', loteId)
            .order('data_moldagem', ascending: false);
    return rows
        .map((e) => QcCorpoProva.fromMap(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<void> saveCp(Map<String, dynamic> data, {String? id}) async {
    if (id != null) {
      await _client.from('qc_corpos_prova').update(data).eq('id', id);
    } else {
      await _client.from('qc_corpos_prova').insert(data);
    }
  }

  Future<void> deleteCp(String id) async {
    await _client.from('qc_corpos_prova').delete().eq('id', id);
  }

  // ---------------------------------------------------------------- Ensaios
  Future<List<QcEnsaio>> listEnsaios({String? loteId}) async {
    if (loteId != null) {
      final cps = await _client
          .from('qc_corpos_prova')
          .select('id')
          .eq('lote_id', loteId);
      final ids = cps.map((e) => e['id'] as String).toList();
      if (ids.isEmpty) return <QcEnsaio>[];
      final rows = await _client
          .from('qc_ensaios')
          .select()
          .inFilter('corpo_prova_id', ids)
          .order('data_ensaio', ascending: false);
      return rows
          .map((e) => QcEnsaio.fromMap(Map<String, dynamic>.from(e)))
          .toList();
    }
    final rows = await _client
        .from('qc_ensaios')
        .select()
        .order('data_ensaio', ascending: false);
    return rows
        .map((e) => QcEnsaio.fromMap(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<void> saveEnsaio(Map<String, dynamic> data, {String? id}) async {
    if (id != null) {
      await _client.from('qc_ensaios').update(data).eq('id', id);
    } else {
      await _client.from('qc_ensaios').insert(data);
    }
  }

  Future<void> deleteEnsaio(String id) async {
    await _client.from('qc_ensaios').delete().eq('id', id);
  }

  // ---------------------------------------------------------------- Padrões
  Future<List<QcPadrao>> listPadroes() async {
    final rows = await _client.from('qc_padroes_codigo').select();
    return rows
        .map((e) => QcPadrao.fromMap(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<void> savePadrao(Map<String, dynamic> data, {String? id}) async {
    if (id != null) {
      await _client.from('qc_padroes_codigo').update(data).eq('id', id);
    } else {
      await _client.from('qc_padroes_codigo').insert(data);
    }
  }

  // ------------------------------------------------- Criação a partir template
  /// Cria os corpos de prova de um lote a partir de um template, respeitando o
  /// padrão de código configurado. Retorna quantos CPs foram criados.
  Future<int> createCpsFromTemplate({
    required String loteId,
    required String dataMoldagem,
    required String templateSlug,
    QcPadrao? padraoCp,
  }) async {
    final tpl = getTemplateBySlug(templateSlug);
    if (tpl == null) throw Exception('Template não encontrado');

    var seq = padraoCp != null &&
            !shouldReset(
              resetModeFromValue(padraoCp.contadorReset),
              padraoCp.ultimoResetData,
            )
        ? padraoCp.contadorAtual
        : 0;

    final rows = <Map<String, dynamic>>[];
    var n = 0;
    for (final item in tpl.itens) {
      for (var i = 0; i < item.qtd; i++) {
        seq += 1;
        n += 1;
        final identificador = padraoCp != null
            ? renderQcCodigo(padraoCp.padrao,
                sigla: padraoCp.sigla, seq: seq)
            : 'CP-${seq.toString().padLeft(2, '0')}';
        rows.add({
          'lote_id': loteId,
          'identificador': identificador,
          'data_moldagem': dataMoldagem,
          'idade_rompimento_dias': item.idadeDias,
          'idade_horas': item.idadeHoras,
          'grupo': item.grupo.value,
          'template_slug': tpl.slug,
          'data_prevista_rompimento':
              addDaysIso(dataMoldagem, item.idadeDias),
        });
      }
    }
    if (rows.isNotEmpty) {
      await _client.from('qc_corpos_prova').insert(rows);
    }
    if (padraoCp != null && n > 0) {
      final today = DateTime.now().toIso8601String().split('T').first;
      await _client.from('qc_padroes_codigo').update({
        'contador_atual': seq,
        'ultimo_reset_data': today,
      }).eq('id', padraoCp.id);
    }
    return n;
  }

  // --------------------------------------------------------- Rastreabilidade
  Future<List<Map<String, dynamic>>> buscarPecas(String termo) async {
    if (termo.length < 2) return [];
    final rows = await _client
        .from('obras_pecas')
        .select(
            'id, identificador, obra_id, qc_lote_id, status, obras(nome), qc_lotes_concreto:qc_lote_id(id, codigo, fck_mpa, data_concretagem)')
        .ilike('identificador', '%$termo%')
        .limit(30);
    return rows.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Future<List<Map<String, dynamic>>> pecasPorLote(String loteId) async {
    final rows = await _client
        .from('obras_pecas')
        .select('id, identificador, status, obra_id, obras(id, nome)')
        .eq('qc_lote_id', loteId)
        .order('identificador');
    return rows.map((e) => Map<String, dynamic>.from(e)).toList();
  }
}
