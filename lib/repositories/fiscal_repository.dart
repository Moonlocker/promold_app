import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/supabase/supabase_service.dart';
import '../models/nota_fiscal.dart';

/// Módulo Fiscal: NFe emitidas/recebidas e configuração.
class FiscalRepository {
  FiscalRepository({SupabaseClient? client})
      : _client = client ?? SupabaseService.client;

  final SupabaseClient _client;

  // ------------------------------------------------------- Notas emitidas
  Future<List<NotaFiscal>> listNotas() async {
    final rows = await _client
        .from('notas_fiscais')
        .select('*, clientes(nome, email, cpf_cnpj, telefone)')
        .order('created_at', ascending: false);
    return rows
        .map((e) => NotaFiscal.fromMap(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<List<NotaFiscalItem>> listItens(String notaId) async {
    final rows = await _client
        .from('notas_fiscais_itens')
        .select()
        .eq('nota_fiscal_id', notaId)
        .order('ordem');
    return rows
        .map((e) => NotaFiscalItem.fromMap(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// Cria uma nota em rascunho com seus itens. Retorna o id da nota.
  Future<String> criarNotaRascunho(
    Map<String, dynamic> nota,
    List<Map<String, dynamic>> itens,
  ) async {
    final row = await _client
        .from('notas_fiscais')
        .insert({...nota, 'status': 'rascunho'})
        .select('id')
        .single();
    final notaId = row['id'] as String;
    if (itens.isNotEmpty) {
      await _client.from('notas_fiscais_itens').insert(
            itens.map((e) => {...e, 'nota_fiscal_id': notaId}).toList(),
          );
    }
    return notaId;
  }

  Future<void> atualizarNotaRascunho(
    String notaId,
    Map<String, dynamic> nota,
    List<Map<String, dynamic>> itens,
  ) async {
    await _client.from('notas_fiscais').update(nota).eq('id', notaId);
    await _client.from('notas_fiscais_itens').delete().eq('nota_fiscal_id', notaId);
    if (itens.isNotEmpty) {
      await _client.from('notas_fiscais_itens').insert(
            itens.map((e) => {...e, 'nota_fiscal_id': notaId}).toList(),
          );
    }
  }

  /// Executa uma ação na edge function `emitir-nfe`.
  Future<Map<String, dynamic>> acaoNfe(
    String acao,
    Map<String, dynamic> body,
  ) async {
    final res = await _client.functions.invoke(
      'emitir-nfe',
      body: {'acao': acao, ...body},
    );
    final data = res.data;
    if (data is Map && data['error'] != null) {
      throw Exception(data['error']);
    }
    if (data is Map) return Map<String, dynamic>.from(data);
    return <String, dynamic>{};
  }

  // ------------------------------------------------------ Notas recebidas
  Future<List<NotaFiscalRecebida>> listRecebidas() async {
    final rows = await _client
        .from('notas_fiscais_recebidas')
        .select()
        .order('data_emissao', ascending: false);
    return rows
        .map((e) => NotaFiscalRecebida.fromMap(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<Map<String, dynamic>> sincronizarRecebidas() async {
    final res = await _client.functions.invoke(
      'consultar-nfe-recebidas',
      body: {'acao': 'listar'},
    );
    final data = res.data;
    if (data is Map && data['error'] != null) {
      throw Exception(data['error']);
    }
    if (data is Map) return Map<String, dynamic>.from(data);
    return <String, dynamic>{};
  }

  Future<Map<String, dynamic>> manifestar({
    required String chave,
    required String tipo,
    String? justificativa,
  }) async {
    final res = await _client.functions.invoke(
      'consultar-nfe-recebidas',
      body: {
        'acao': 'manifestar',
        'chave': chave,
        'tipo': tipo,
        'justificativa': justificativa,
      },
    );
    final data = res.data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return <String, dynamic>{};
  }

  // ----------------------------------------------------- Configuração fiscal
  Future<Map<String, dynamic>?> getConfig() async {
    final row =
        await _client.from('fiscal_configuracoes').select().maybeSingle();
    return row == null ? null : Map<String, dynamic>.from(row);
  }

  Future<void> saveConfig(Map<String, dynamic> data, {String? id}) async {
    if (id != null) {
      await _client.from('fiscal_configuracoes').update(data).eq('id', id);
    } else {
      await _client.from('fiscal_configuracoes').insert(data);
    }
  }

  Future<String> uploadCertificado({
    required Uint8List bytes,
    required String nomeArquivo,
  }) async {
    final path =
        'certificados/${DateTime.now().millisecondsSinceEpoch}-$nomeArquivo';
    await _client.storage.from('empresa').uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(),
        );
    return _client.storage.from('empresa').getPublicUrl(path);
  }
}
