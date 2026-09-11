import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/supabase/supabase_service.dart';
import '../models/conta_financeira.dart';

/// Financeiro: contas a pagar/receber, integração Asaas e conciliação.
class FinanceiroRepository {
  FinanceiroRepository({SupabaseClient? client})
      : _client = client ?? SupabaseService.client;

  final SupabaseClient _client;

  static String get _hoje {
    final now = DateTime.now();
    return '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }

  String _tabela(String tipo) =>
      tipo == 'pagar' ? 'contas_pagar' : 'contas_receber';

  // ------------------------------------------------------------------- Contas
  Future<List<ContaFinanceira>> listContas(String tipo) async {
    final rows = await _client
        .from(_tabela(tipo))
        .select()
        .order('data_vencimento', ascending: true);
    return rows
        .map((e) =>
            ContaFinanceira.fromMap(Map<String, dynamic>.from(e), tipo))
        .toList();
  }

  Future<void> createConta(String tipo, Map<String, dynamic> data) async {
    await _client.from(_tabela(tipo)).insert(data);
  }

  Future<void> createParcelas(String tipo, List<Map<String, dynamic>> data) async {
    await _client.from(_tabela(tipo)).insert(data);
  }

  Future<void> updateConta(
    String tipo,
    String id,
    Map<String, dynamic> data,
  ) async {
    await _client.from(_tabela(tipo)).update(data).eq('id', id);
  }

  Future<void> deleteConta(String tipo, String id) async {
    await _client.from(_tabela(tipo)).delete().eq('id', id);
  }

  /// Registra (parcial ou total) a liquidação de uma conta.
  Future<void> registrarLiquidacao(
    ContaFinanceira conta, {
    required double valor,
    required String data,
    required String metodo,
  }) async {
    final novo = conta.liquidado + valor;
    final total = conta.valor;
    final novoStatus = novo >= total
        ? (conta.isPagar ? 'pago' : 'recebido')
        : 'parcial';
    if (conta.isPagar) {
      await _client.from('contas_pagar').update({
        'valor_pago': novo.clamp(0, total),
        'status': novoStatus,
        'data_pagamento': data,
        'metodo_pagamento': metodo,
      }).eq('id', conta.id);
    } else {
      await _client.from('contas_receber').update({
        'valor_recebido': novo.clamp(0, total),
        'status': novoStatus,
        'data_recebimento': data,
        'metodo_recebimento': metodo,
      }).eq('id', conta.id);
    }
  }

  /// Edita os dados da liquidação já registrada.
  Future<void> editarLiquidacao(
    ContaFinanceira conta, {
    required double valor,
    required String data,
    required String metodo,
  }) async {
    final total = conta.valor;
    final novoStatus = valor <= 0
        ? 'pendente'
        : valor >= total
            ? (conta.isPagar ? 'pago' : 'recebido')
            : 'parcial';
    if (conta.isPagar) {
      await _client.from('contas_pagar').update({
        'valor_pago': valor.clamp(0, total),
        'data_pagamento': valor > 0 ? data : null,
        'metodo_pagamento': valor > 0 ? metodo : null,
        'status': novoStatus,
      }).eq('id', conta.id);
    } else {
      await _client.from('contas_receber').update({
        'valor_recebido': valor.clamp(0, total),
        'data_recebimento': valor > 0 ? data : null,
        'metodo_recebimento': valor > 0 ? metodo : null,
        'status': novoStatus,
      }).eq('id', conta.id);
    }
  }

  /// Reverte a conta para pendente, zerando os valores liquidados.
  Future<void> reverter(ContaFinanceira conta) async {
    if (conta.isPagar) {
      await _client.from('contas_pagar').update({
        'valor_pago': 0,
        'data_pagamento': null,
        'metodo_pagamento': null,
        'status': 'pendente',
      }).eq('id', conta.id);
    } else {
      await _client.from('contas_receber').update({
        'valor_recebido': 0,
        'data_recebimento': null,
        'metodo_recebimento': null,
        'status': 'pendente',
      }).eq('id', conta.id);
    }
  }

  // ------------------------------------------------------------ Asaas / PIX
  /// Gera (ou reaproveita) cobrança PIX/Boleto no Asaas para uma conta a receber.
  /// Retorna o JSON da edge function `cliente-asaas-cobranca`.
  Future<Map<String, dynamic>> gerarCobrancaAsaas({
    required String contaId,
    required String billingType,
    bool forceRegenerate = false,
  }) async {
    final res = await _client.functions.invoke(
      'cliente-asaas-cobranca',
      body: {
        'conta_id': contaId,
        'billing_type': billingType,
        'force_regenerate': forceRegenerate,
      },
    );
    final data = res.data;
    if (data is Map && data['error'] != null) {
      throw Exception(data['error']);
    }
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return <String, dynamic>{};
  }

  // ------------------------------------------------------- Integrações Asaas
  Future<Map<String, dynamic>?> getIntegracao() async {
    final row = await _client
        .from('financeiro_integracoes')
        .select()
        .maybeSingle();
    return row == null ? null : Map<String, dynamic>.from(row);
  }

  Future<void> saveIntegracao(
    Map<String, dynamic> payload, {
    String? id,
  }) async {
    if (id != null) {
      await _client.from('financeiro_integracoes').update(payload).eq('id', id);
    } else {
      await _client.from('financeiro_integracoes').insert(payload);
    }
  }

  /// Confirma a conciliação de um lançamento de extrato com uma conta.
  Future<void> conciliar({
    required String tipo,
    required ContaFinanceira conta,
    required double valor,
    required String data,
  }) async {
    final novo = conta.liquidado + valor;
    final total = conta.valor;
    final novoStatus = novo >= total
        ? (tipo == 'pagar' ? 'pago' : 'recebido')
        : 'parcial';
    if (tipo == 'pagar') {
      await _client.from('contas_pagar').update({
        'valor_pago': novo.clamp(0, total),
        'status': novoStatus,
        if (novoStatus == 'pago') 'data_pagamento': data,
      }).eq('id', conta.id);
    } else {
      await _client.from('contas_receber').update({
        'valor_recebido': novo.clamp(0, total),
        'status': novoStatus,
        if (novoStatus == 'recebido') 'data_recebimento': data,
      }).eq('id', conta.id);
    }
  }

  /// Contas em aberto (pendentes/parciais) para conciliação.
  Future<List<ContaFinanceira>> listContasAbertas(String tipo) async {
    final rows = await _client
        .from(_tabela(tipo))
        .select()
        .inFilter('status', ['pendente', 'parcial']).order('data_vencimento');
    return rows
        .map((e) =>
            ContaFinanceira.fromMap(Map<String, dynamic>.from(e), tipo))
        .toList();
  }

  static String get hoje => _hoje;
}
