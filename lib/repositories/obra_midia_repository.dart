import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/supabase/supabase_service.dart';
import '../models/obra_midia.dart';

/// Fotos e anexos de obra, incluindo upload/remoção no Supabase Storage.
///
/// Convenções de caminho idênticas ao webapp:
///  - fotos:  `obra-<obraId>/<timestamp>-<ext>`
///  - anexos: `obra-<obraId>/<timestamp>-<nomeOriginal>`
/// Sem prefixo de organização — o isolamento é feito pela RLS do Storage.
class ObraMidiaRepository {
  ObraMidiaRepository({SupabaseClient? client})
      : _client = client ?? SupabaseService.client;

  final SupabaseClient _client;

  static const bucketFotos = 'obras-fotos';
  static const bucketAnexos = 'obras-anexos';

  // ---------------------------------------------------------------- Fotos
  Future<List<ObraFoto>> listFotos(String obraId) async {
    final rows = await _client
        .from('obras_fotos')
        .select()
        .eq('obra_id', obraId)
        .order('created_at', ascending: false);
    return rows.map((e) => ObraFoto.fromMap(Map<String, dynamic>.from(e))).toList();
  }

  Future<void> addFoto(Map<String, dynamic> data) async {
    await _client.from('obras_fotos').insert(data);
  }

  Future<void> updateFoto(String id, Map<String, dynamic> data) async {
    await _client.from('obras_fotos').update(data).eq('id', id);
  }

  Future<void> deleteFoto(String id) async {
    await _client.from('obras_fotos').delete().eq('id', id);
  }

  // --------------------------------------------------------------- Anexos
  Future<List<ObraAnexo>> listAnexos(String obraId) async {
    final rows = await _client
        .from('obras_anexos')
        .select()
        .eq('obra_id', obraId)
        .order('created_at', ascending: false);
    return rows
        .map((e) => ObraAnexo.fromMap(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<void> addAnexo(Map<String, dynamic> data) async {
    await _client.from('obras_anexos').insert(data);
  }

  Future<void> updateAnexo(String id, Map<String, dynamic> data) async {
    await _client.from('obras_anexos').update(data).eq('id', id);
  }

  Future<void> deleteAnexo(String id) async {
    await _client.from('obras_anexos').delete().eq('id', id);
  }

  // --------------------------------------------------------------- Storage
  Future<String> uploadFoto({
    required String obraId,
    required Uint8List bytes,
    required String extensao,
    String? contentType,
  }) {
    final path =
        'obra-$obraId/${DateTime.now().millisecondsSinceEpoch}.$extensao';
    return _upload(bucketFotos, path, bytes, contentType);
  }

  Future<String> uploadAnexo({
    required String obraId,
    required Uint8List bytes,
    required String nomeArquivo,
    String? contentType,
  }) {
    final path = 'obra-$obraId/${DateTime.now().millisecondsSinceEpoch}-$nomeArquivo';
    return _upload(bucketAnexos, path, bytes, contentType);
  }

  /// PDF vinculado a uma peça (`obras_pecas.pdf_url` / `pdf_storage_path`).
  Future<String> uploadPecaPdf({
    required String obraId,
    required String pecaId,
    required Uint8List bytes,
  }) {
    final path =
        '$obraId/peca-pdf/$pecaId-${DateTime.now().millisecondsSinceEpoch}.pdf';
    return _upload(bucketAnexos, path, bytes, 'application/pdf');
  }

  Future<void> removePecaPdf(String storagePath) async {
    await _client.storage.from(bucketAnexos).remove([storagePath]);
  }

  Future<String> _upload(
    String bucket,
    String path,
    Uint8List bytes,
    String? contentType,
  ) async {
    await _client.storage.from(bucket).uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            upsert: false,
            contentType: contentType,
          ),
        );
    return _client.storage.from(bucket).getPublicUrl(path);
  }

  /// Remove um arquivo a partir da URL pública.
  Future<void> removeByUrl(String bucket, String url) async {
    final marker = '/storage/v1/object/public/$bucket/';
    final index = url.indexOf(marker);
    if (index < 0) return;
    final path = url.substring(index + marker.length);
    if (path.isEmpty) return;
    await _client.storage.from(bucket).remove([path]);
  }
}
