import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/supabase/supabase_service.dart';
import '../models/estoque.dart';

/// Estoque: locais de armazenamento, vínculo de peças e mapa visual.
class EstoqueRepository {
  EstoqueRepository({SupabaseClient? client})
      : _client = client ?? SupabaseService.client;

  final SupabaseClient _client;

  static const _bucket = 'obras-fotos';
  static const _nomeLink = '__mapa_link_estoque__';

  // --------------------------------------------------------------- Estoques
  Future<List<Estoque>> listEstoques() async {
    final rows = await _client
        .from('estoques')
        .select()
        .neq('nome', Estoque.nomeSistema)
        .order('nome');
    return rows.map((e) => Estoque.fromMap(Map<String, dynamic>.from(e))).toList();
  }

  Future<Estoque> createEstoque(Map<String, dynamic> data) async {
    final row = await _client.from('estoques').insert(data).select().single();
    return Estoque.fromMap(Map<String, dynamic>.from(row));
  }

  Future<void> updateEstoque(String id, Map<String, dynamic> data) async {
    await _client.from('estoques').update(data).eq('id', id);
  }

  Future<void> duplicateEstoque(Estoque estoque) async {
    await _client.from('estoques').insert({
      'nome': '${estoque.nome} (cópia)',
      'descricao': estoque.descricao,
      'capacidade': estoque.capacidade,
    });
  }

  Future<void> deleteEstoque(String id) async {
    await _client.from('obras_pecas').update({'estoque_id': null}).eq(
          'estoque_id',
          id,
        );
    await _client.from('estoques').delete().eq('id', id);
  }

  /// Id do estoque "sistema" que hospeda o mapa visual, criando se necessário.
  Future<String> getSystemEstoqueId() async {
    final existing = await _client
        .from('estoques')
        .select('id')
        .eq('nome', Estoque.nomeSistema)
        .maybeSingle();
    if (existing != null) return existing['id'] as String;
    final created = await _client.from('estoques').insert({
      'nome': Estoque.nomeSistema,
      'descricao': 'Sistema - Mapa Visual',
      'ativo': false,
    }).select('id').single();
    return created['id'] as String;
  }

  // ------------------------------------------------------------- Peças
  Future<List<PecaEmEstoque>> listPecasEmEstoque() async {
    final rows = await _client
        .from('obras_pecas')
        .select(
            'id, obra_id, peca_catalogo_id, identificador, comprimento, data_concretagem, estoque_id, status, pecas_catalogo(nome, categoria_id), obras(nome, cor)')
        .eq('status', 'em_estoque')
        .order('identificador');
    return rows
        .map((e) => PecaEmEstoque.fromMap(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<void> linkPeca(String pecaId, String estoqueId) async {
    await _client
        .from('obras_pecas')
        .update({'estoque_id': estoqueId}).eq('id', pecaId);
  }

  Future<void> unlinkPeca(String pecaId) async {
    await _client
        .from('obras_pecas')
        .update({'estoque_id': null}).eq('id', pecaId);
  }

  // -------------------------------------------------------- Compartimentos
  Future<List<Compartimento>> listCompartimentos(String estoqueId) async {
    final rows = await _client
        .from('compartimentos')
        .select()
        .eq('estoque_id', estoqueId)
        .neq('nome', _nomeLink)
        .order('nome');
    return rows
        .map((e) => Compartimento.fromMap(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<void> createCompartimento(
    String estoqueId,
    Map<String, dynamic> data,
  ) async {
    await _client
        .from('compartimentos')
        .insert({'estoque_id': estoqueId, ...data});
  }

  Future<void> updateCompartimento(String id, Map<String, dynamic> data) async {
    await _client.from('compartimentos').update(data).eq('id', id);
  }

  Future<void> deleteCompartimento(String id) async {
    await _client.from('compartimentos').delete().eq('id', id);
  }

  // --------------------------------------------------------- Imagem do local
  Future<String> uploadImagemEstoque({
    required String estoqueId,
    required Uint8List bytes,
    required String extensao,
  }) async {
    final path =
        'estoque-$estoqueId-${DateTime.now().millisecondsSinceEpoch}.$extensao';
    await _client.storage.from(_bucket).uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: 'image/$extensao'),
        );
    return _client.storage.from(_bucket).getPublicUrl(path);
  }

  Future<void> setImagemEstoque(
    String estoqueId,
    String? url,
    String descricaoLimpa,
  ) async {
    final base = descricaoLimpa.trim();
    final nova = url == null
        ? (base.isEmpty ? null : base)
        : '[IMG:$url]${base.isEmpty ? '' : ' $base'}';
    await _client
        .from('estoques')
        .update({'descricao': nova}).eq('id', estoqueId);
  }

  Future<void> removeImagemEstoque(String url) async {
    const marker = '/storage/v1/object/public/$_bucket/';
    final idx = url.indexOf(marker);
    if (idx < 0) return;
    await _client.storage.from(_bucket).remove([url.substring(idx + marker.length)]);
  }

  // ------------------------------------------------------------- Mapa visual
  Future<EstoqueVisualConfig?> getConfig(String estoqueId) async {
    final row = await _client
        .from('estoque_visual_config')
        .select()
        .eq('estoque_id', estoqueId)
        .maybeSingle();
    if (row == null) return null;
    return EstoqueVisualConfig.fromMap(Map<String, dynamic>.from(row));
  }

  Future<void> saveConfig(
    String estoqueId,
    Map<String, dynamic> data,
  ) async {
    final existing = await _client
        .from('estoque_visual_config')
        .select('id')
        .eq('estoque_id', estoqueId)
        .maybeSingle();
    if (existing != null) {
      await _client
          .from('estoque_visual_config')
          .update(data)
          .eq('id', existing['id'] as String);
    } else {
      await _client
          .from('estoque_visual_config')
          .insert({'estoque_id': estoqueId, ...data});
    }
  }

  Future<List<EstoqueVisualElemento>> listElementos(String estoqueId) async {
    final rows = await _client
        .from('estoque_visual_elementos')
        .select()
        .eq('estoque_id', estoqueId)
        .order('created_at');
    final links = await loadCompartimentoLinks();
    return rows.map((e) {
      final el = EstoqueVisualElemento.fromMap(Map<String, dynamic>.from(e));
      return el.copyWith(
        linkedEstoqueId: el.compartimentoId != null
            ? links[el.compartimentoId]
            : null,
      );
    }).toList();
  }

  Future<void> saveElementos(
    String estoqueId,
    List<EstoqueVisualElemento> elementos,
  ) async {
    await _client
        .from('estoque_visual_elementos')
        .delete()
        .eq('estoque_id', estoqueId);

    final rows = <Map<String, dynamic>>[];
    for (final el in elementos) {
      String? compartimentoId;
      if (el.linkedEstoqueId != null) {
        compartimentoId = await ensureLinkCompartimento(el.linkedEstoqueId!);
      }
      rows.add({
        'id': el.id,
        'estoque_id': estoqueId,
        'compartimento_id': compartimentoId,
        'tipo': el.tipo,
        'x': el.x,
        'y': el.y,
        'largura': el.largura,
        'altura': el.altura,
        'rotacao': el.rotacao,
        'label': el.label,
      });
    }
    if (rows.isNotEmpty) {
      await _client.from('estoque_visual_elementos').insert(rows);
    }
  }

  Future<String> ensureLinkCompartimento(String targetEstoqueId) async {
    final existing = await _client
        .from('compartimentos')
        .select('id')
        .eq('estoque_id', targetEstoqueId)
        .eq('nome', _nomeLink)
        .limit(1)
        .maybeSingle();
    if (existing != null) return existing['id'] as String;
    final created = await _client.from('compartimentos').insert({
      'estoque_id': targetEstoqueId,
      'nome': _nomeLink,
      'descricao': 'Sistema - vínculo visual',
      'ocupado': false,
    }).select('id').single();
    return created['id'] as String;
  }

  /// Mapa `compartimento_id → estoque_id`.
  Future<Map<String, String>> loadCompartimentoLinks() async {
    final rows = await _client
        .from('compartimentos')
        .select('id, estoque_id')
        .not('estoque_id', 'is', null);
    final map = <String, String>{};
    for (final row in rows) {
      final id = row['id'] as String?;
      final estoqueId = row['estoque_id'] as String?;
      if (id != null && estoqueId != null) map[id] = estoqueId;
    }
    return map;
  }

  Future<String> uploadBackground({
    required String estoqueId,
    required Uint8List bytes,
    required String nomeArquivo,
  }) async {
    final path =
        'estoque-bg/$estoqueId/${DateTime.now().millisecondsSinceEpoch}-$nomeArquivo';
    await _client.storage.from(_bucket).uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(),
        );
    return _client.storage.from(_bucket).getPublicUrl(path);
  }
}
