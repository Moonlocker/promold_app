import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/supabase/supabase_service.dart';
import '../models/processo_etapa.dart';

/// Processos/etapas manuais e seus status por obra.
class ProcessosRepository {
  ProcessosRepository({SupabaseClient? client})
      : _client = client ?? SupabaseService.client;

  final SupabaseClient _client;

  Future<List<ProcessoEtapa>> listProcessos() async {
    final rows = await _client
        .from('processos_etapas')
        .select()
        .order('ordem', ascending: true);
    return rows
        .map((e) => ProcessoEtapa.fromMap(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<List<ProcessoEtapaItem>> listItens() async {
    final rows = await _client
        .from('processos_etapas_itens')
        .select()
        .order('ordem', ascending: true);
    return rows
        .map((e) => ProcessoEtapaItem.fromMap(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<List<ObraEtapaStatus>> listStatus() async {
    final rows = await _client.from('obra_etapa_status').select();
    return rows
        .map((e) => ObraEtapaStatus.fromMap(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<void> upsertStatus({
    required String obraId,
    required String etapaItemId,
    required String status,
  }) async {
    final existing = await _client
        .from('obra_etapa_status')
        .select('id')
        .eq('obra_id', obraId)
        .eq('etapa_item_id', etapaItemId)
        .maybeSingle();
    if (existing != null) {
      await _client
          .from('obra_etapa_status')
          .update({'status': status})
          .eq('id', existing['id'] as String);
    } else {
      await _client.from('obra_etapa_status').insert({
        'obra_id': obraId,
        'etapa_item_id': etapaItemId,
        'status': status,
      });
    }
  }
}
