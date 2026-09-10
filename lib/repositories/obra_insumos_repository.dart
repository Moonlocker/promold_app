import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/supabase/supabase_service.dart';
import '../models/obra_historico.dart';

/// Insumos de obra (tabela `obras_insumos`).
class ObraInsumosRepository {
  ObraInsumosRepository({SupabaseClient? client})
      : _client = client ?? SupabaseService.client;

  final SupabaseClient _client;

  Future<List<ObraInsumo>> list(String obraId) async {
    final rows = await _client
        .from('obras_insumos')
        .select()
        .eq('obra_id', obraId)
        .order('created_at', ascending: false);
    return rows
        .map((e) => ObraInsumo.fromMap(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<void> save(Map<String, dynamic> data) async {
    final id = data['id'] as String?;
    if (id != null && id.isNotEmpty) {
      final patch = Map<String, dynamic>.from(data)..remove('id');
      await _client.from('obras_insumos').update(patch).eq('id', id);
    } else {
      final insert = Map<String, dynamic>.from(data)..remove('id');
      await _client.from('obras_insumos').insert(insert);
    }
  }

  Future<void> delete(String id) async {
    await _client.from('obras_insumos').delete().eq('id', id);
  }
}
