import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/supabase/supabase_service.dart';
import '../models/capacidade.dart';

/// Capacidade da fábrica: áreas produtivas e capacidades.
class CapacidadeRepository {
  CapacidadeRepository({SupabaseClient? client})
      : _client = client ?? SupabaseService.client;

  final SupabaseClient _client;

  Future<List<AreaProdutiva>> listAreas() async {
    final rows = await _client.from('areas_produtivas').select().order('nome');
    return rows
        .map((e) => AreaProdutiva.fromMap(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<void> createArea(Map<String, dynamic> data) async {
    await _client.from('areas_produtivas').insert(data);
  }

  Future<void> updateArea(String id, Map<String, dynamic> data) async {
    await _client.from('areas_produtivas').update(data).eq('id', id);
  }

  Future<void> deleteArea(String id) async {
    await _client.from('capacidade_fabrica').delete().eq('area_produtiva_id', id);
    await _client.from('areas_produtivas').delete().eq('id', id);
  }

  Future<List<CapacidadeFabrica>> listCapacidades() async {
    final rows = await _client.from('capacidade_fabrica').select();
    return rows
        .map((e) => CapacidadeFabrica.fromMap(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<void> saveCapacidade({
    required String areaId,
    required double capacidadeDiaria,
    double? capacidadeSemanal,
  }) async {
    final existing = await _client
        .from('capacidade_fabrica')
        .select('id')
        .eq('area_produtiva_id', areaId)
        .maybeSingle();
    final payload = {
      'area_produtiva_id': areaId,
      'capacidade_diaria': capacidadeDiaria,
      'capacidade_semanal': capacidadeSemanal,
      'ativa': true,
    };
    if (existing != null) {
      await _client
          .from('capacidade_fabrica')
          .update(payload)
          .eq('id', existing['id'] as String);
    } else {
      await _client.from('capacidade_fabrica').insert(payload);
    }
  }
}
