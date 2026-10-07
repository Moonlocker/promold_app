import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/supabase/supabase_service.dart';
import '../models/sistema.dart';
import '../models/veiculo.dart';

/// Repositório dos módulos de Sistema/Extras: frota, suporte, configurações,
/// faturas SaaS e orçamentos.
class SistemaRepository {
  SistemaRepository({SupabaseClient? client})
      : _client = client ?? SupabaseService.client;

  final SupabaseClient _client;

  // ------------------------------------------------------------------ Frota
  Future<List<Veiculo>> listVeiculos() async {
    final rows = await _client.from('veiculos').select().order('placa');
    return rows.map((e) => Veiculo.fromMap(Map<String, dynamic>.from(e))).toList();
  }

  Future<void> createVeiculo(Map<String, dynamic> data) async {
    await _client.from('veiculos').insert(data);
  }

  Future<void> updateVeiculo(String id, Map<String, dynamic> data) async {
    await _client.from('veiculos').update(data).eq('id', id);
  }

  Future<void> deleteVeiculo(String id) async {
    await _client.from('veiculos').delete().eq('id', id);
  }

  // --------------------------------------------------------------- Suporte
  Future<List<SupportTicket>> listTickets() async {
    final rows = await _client
        .from('support_tickets')
        .select()
        .order('created_at', ascending: false);
    return rows
        .map((e) => SupportTicket.fromMap(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<String> createTicket(Map<String, dynamic> data) async {
    final row =
        await _client.from('support_tickets').insert(data).select('id').single();
    return row['id'] as String;
  }

  Future<void> updateTicket(String id, Map<String, dynamic> data) async {
    await _client.from('support_tickets').update(data).eq('id', id);
  }

  Future<List<SupportMessage>> listMessages(String ticketId) async {
    final rows = await _client
        .from('support_ticket_messages')
        .select()
        .eq('ticket_id', ticketId)
        .order('created_at');
    return rows
        .map((e) => SupportMessage.fromMap(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<void> sendMessage(Map<String, dynamic> data) async {
    await _client.from('support_ticket_messages').insert(data);
  }

  /// Vídeos tutoriais ativos da plataforma (tabela `tutoriais_videos`).
  Future<List<TutorialVideo>> listTutoriais() async {
    final rows = await _client
        .from('tutoriais_videos')
        .select()
        .eq('ativo', true)
        .order('modulo')
        .order('ordem');
    return rows
        .map((e) => TutorialVideo.fromMap(Map<String, dynamic>.from(e)))
        .toList();
  }

  // --------------------------------------------------------- Configurações
  Future<Map<String, dynamic>?> getOrganizacao(String id) async {
    final row = await _client
        .from('organizacoes')
        .select()
        .eq('id', id)
        .maybeSingle();
    return row == null ? null : Map<String, dynamic>.from(row);
  }

  Future<void> updateOrganizacao(String id, Map<String, dynamic> data) async {
    await _client.from('organizacoes').update(data).eq('id', id);
  }

  Future<Map<String, String>> getConfiguracoes() async {
    final rows = await _client.from('configuracoes').select('chave, valor');
    final map = <String, String>{};
    for (final row in rows) {
      final chave = row['chave'] as String?;
      if (chave != null) map[chave] = (row['valor'] as String?) ?? '';
    }
    return map;
  }

  Future<void> upsertConfiguracao(String chave, String? valor) async {
    final existing = await _client
        .from('configuracoes')
        .select('id')
        .eq('chave', chave)
        .maybeSingle();
    if (existing != null) {
      await _client
          .from('configuracoes')
          .update({'valor': valor}).eq('id', existing['id'] as String);
    } else {
      await _client.from('configuracoes').insert({'chave': chave, 'valor': valor});
    }
  }

  Future<List<Map<String, dynamic>>> listUsuarios() async {
    final rows = await _client
        .from('profiles')
        .select('id, user_id, nome, email, organizacao_id, created_at')
        .order('nome');
    return rows.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  // -------------------------------------------------------------- Faturas
  Future<List<FaturaSaas>> listFaturas() async {
    final rows = await _client
        .from('faturas_saas')
        .select()
        .order('ano', ascending: false)
        .order('mes', ascending: false);
    return rows
        .map((e) => FaturaSaas.fromMap(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// Gera cobrança (PIX/Boleto) para a fatura via edge function.
  Future<Map<String, dynamic>> gerarCobrancaFatura({
    required String faturaId,
    required String metodo,
  }) async {
    final res = await _client.functions.invoke(
      'criar-cobranca-asaas',
      body: {'fatura_id': faturaId, 'metodo': metodo},
    );
    final data = res.data;
    if (data is Map && data['error'] != null) {
      throw Exception(data['error']);
    }
    if (data is Map) return Map<String, dynamic>.from(data);
    return <String, dynamic>{};
  }

  // ----------------------------------------------------------- Orçamentos
  Future<List<Orcamento>> listOrcamentos() async {
    final rows = await _client
        .from('orcamentos')
        .select()
        .order('created_at', ascending: false);
    return rows
        .map((e) => Orcamento.fromMap(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<List<Map<String, dynamic>>> listOrcamentoItens(String orcamentoId) async {
    final rows = await _client
        .from('orcamentos_itens')
        .select('*, pecas_catalogo(nome, identificador_padrao)')
        .eq('orcamento_id', orcamentoId);
    return rows.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Future<Orcamento?> getOrcamento(String id) async {
    final row =
        await _client.from('orcamentos').select().eq('id', id).maybeSingle();
    return row == null ? null : Orcamento.fromMap(Map<String, dynamic>.from(row));
  }

  Future<void> addOrcamentoItem(
    String orcamentoId,
    Map<String, dynamic> data,
  ) async {
    await _client
        .from('orcamentos_itens')
        .insert({'orcamento_id': orcamentoId, ...data});
  }

  Future<void> updateOrcamentoItem(String id, Map<String, dynamic> data) async {
    await _client.from('orcamentos_itens').update(data).eq('id', id);
  }

  Future<void> deleteOrcamentoItem(String id) async {
    await _client.from('orcamentos_itens').delete().eq('id', id);
  }

  Future<void> createOrcamento(Map<String, dynamic> data) async {
    await _client.from('orcamentos').insert(data);
  }

  Future<void> updateOrcamento(String id, Map<String, dynamic> data) async {
    await _client.from('orcamentos').update(data).eq('id', id);
  }

  Future<void> deleteOrcamento(String id) async {
    await _client.from('orcamentos').delete().eq('id', id);
  }

  // --------------------------------------------- Anexos do orçamento
  Future<List<Map<String, dynamic>>> listOrcamentoAnexos(
    String orcamentoId,
  ) async {
    final rows = await _client
        .from('orcamentos_anexos')
        .select()
        .eq('orcamento_id', orcamentoId)
        .order('created_at');
    return rows.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Future<void> addOrcamentoAnexo(Map<String, dynamic> data) async {
    await _client.from('orcamentos_anexos').insert(data);
  }

  Future<void> updateOrcamentoAnexo(
    String id,
    Map<String, dynamic> data,
  ) async {
    await _client.from('orcamentos_anexos').update(data).eq('id', id);
  }

  Future<void> deleteOrcamentoAnexo(String id) async {
    await _client.from('orcamentos_anexos').delete().eq('id', id);
  }

  Future<String> uploadOrcamentoAnexo({
    required String orcamentoId,
    required Uint8List bytes,
    required String nomeArquivo,
    String? contentType,
  }) async {
    final path =
        '$orcamentoId/${DateTime.now().millisecondsSinceEpoch}-$nomeArquivo';
    await _client.storage.from('orcamentos_anexos').uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(upsert: false, contentType: contentType),
        );
    return _client.storage.from('orcamentos_anexos').getPublicUrl(path);
  }

  /// Remove um arquivo do Storage a partir da URL pública.
  Future<void> removeStorageByUrl(String bucket, String url) async {
    final marker = '/storage/v1/object/public/$bucket/';
    final index = url.indexOf(marker);
    if (index < 0) return;
    final path = url.substring(index + marker.length);
    if (path.isEmpty) return;
    await _client.storage.from(bucket).remove([path]);
  }

  // ------------------------------------------ Histórico de acessos
  Future<List<Map<String, dynamic>>> listOrcamentoAcessoLog(
    String orcamentoId,
  ) async {
    final rows = await _client
        .from('orcamento_acesso_log')
        .select()
        .eq('orcamento_id', orcamentoId)
        .order('created_at', ascending: false)
        .limit(50);
    return rows.map((e) => Map<String, dynamic>.from(e)).toList();
  }
}
