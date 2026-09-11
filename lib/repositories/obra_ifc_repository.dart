import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/supabase/supabase_service.dart';
import '../models/obra_ifc.dart';

/// Arquivos IFC anexados às obras (bucket `obras-ifc`).
class ObraIfcRepository {
  ObraIfcRepository({SupabaseClient? client})
      : _client = client ?? SupabaseService.client;

  final SupabaseClient _client;

  static const _bucket = 'obras-ifc';

  Future<List<ObraIfcArquivo>> listByObra(String obraId) async {
    final rows = await _client
        .from('obras_ifc_arquivos')
        .select()
        .eq('obra_id', obraId)
        .order('created_at', ascending: false);
    return rows
        .map((e) => ObraIfcArquivo.fromMap(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<ObraIfcArquivo> upload({
    required String obraId,
    required Uint8List bytes,
    required String nomeArquivo,
  }) async {
    final ext = nomeArquivo.contains('.')
        ? nomeArquivo.split('.').last
        : 'ifc';
    final path =
        '$obraId/${DateTime.now().millisecondsSinceEpoch}-${DateTime.now().microsecond}.$ext';
    await _client.storage.from(_bucket).uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(contentType: 'application/octet-stream'),
        );
    final url = _client.storage.from(_bucket).getPublicUrl(path);
    // Apenas um arquivo ativo por obra.
    await _client
        .from('obras_ifc_arquivos')
        .update({'ativo': false}).eq('obra_id', obraId);
    final row = await _client
        .from('obras_ifc_arquivos')
        .insert({
          'obra_id': obraId,
          'nome': nomeArquivo,
          'url': url,
          'storage_path': path,
          'tamanho_bytes': bytes.length,
          'ativo': true,
        })
        .select()
        .single();
    return ObraIfcArquivo.fromMap(Map<String, dynamic>.from(row));
  }

  Future<void> setAtivo(String id, String obraId) async {
    await _client
        .from('obras_ifc_arquivos')
        .update({'ativo': false}).eq('obra_id', obraId);
    await _client
        .from('obras_ifc_arquivos')
        .update({'ativo': true}).eq('id', id);
  }

  Future<void> rename(String id, String nome) async {
    await _client
        .from('obras_ifc_arquivos')
        .update({'nome': nome}).eq('id', id);
  }

  Future<void> saveViewerState(String id, Map<String, dynamic> state) async {
    await _client
        .from('obras_ifc_arquivos')
        .update({'viewer_state': state}).eq('id', id);
  }

  Future<void> delete(ObraIfcArquivo arquivo) async {
    if (arquivo.storagePath != null) {
      try {
        await _client.storage.from(_bucket).remove([arquivo.storagePath!]);
      } catch (_) {
        // ignora falha de storage; remove o registro mesmo assim
      }
    }
    await _client.from('obras_ifc_arquivos').delete().eq('id', arquivo.id);
  }
}
