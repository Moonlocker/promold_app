import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/supabase/supabase_service.dart';
import '../models/mapa_montagem.dart';

/// Mapa de Montagem: vistas e células (posições das peças).
class MapaMontagemRepository {
  MapaMontagemRepository({SupabaseClient? client})
      : _client = client ?? SupabaseService.client;

  final SupabaseClient _client;

  Future<List<MapaMontagemVista>> listVistas(String obraId) async {
    final rows = await _client
        .from('mapa_montagem_vistas')
        .select()
        .eq('obra_id', obraId)
        .order('ordem');
    return rows
        .map((e) => MapaMontagemVista.fromMap(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<MapaMontagemVista> createVista(
    String obraId,
    Map<String, dynamic> data,
  ) async {
    final row = await _client
        .from('mapa_montagem_vistas')
        .insert({'obra_id': obraId, ...data})
        .select()
        .single();
    return MapaMontagemVista.fromMap(Map<String, dynamic>.from(row));
  }

  Future<void> deleteVista(String id) async {
    await _client.from('mapa_montagem_celulas').delete().eq('vista_id', id);
    await _client.from('mapa_montagem_vistas').delete().eq('id', id);
  }

  Future<List<MapaMontagemCelula>> listCelulas(String vistaId) async {
    final rows = await _client
        .from('mapa_montagem_celulas')
        .select()
        .eq('vista_id', vistaId);
    return rows
        .map((e) => MapaMontagemCelula.fromMap(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// Substitui todas as células da vista.
  Future<void> saveCelulas(
    String vistaId,
    String obraId,
    List<MapaMontagemCelula> celulas,
  ) async {
    await _client.from('mapa_montagem_celulas').delete().eq('vista_id', vistaId);
    final ocupadas = celulas.where((c) => !c.vazia).toList();
    if (ocupadas.isEmpty) return;
    await _client.from('mapa_montagem_celulas').insert(
          ocupadas
              .map((c) => {
                    'vista_id': vistaId,
                    'obra_id': obraId,
                    'linha': c.linha,
                    'coluna': c.coluna,
                    'obra_peca_id': c.obraPecaId,
                    'peca_catalogo_id': c.pecaCatalogoId,
                    'identificador': c.identificador,
                    'status': c.status,
                  })
              .toList(),
        );
  }
}
