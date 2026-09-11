/// Conta financeira (tabelas `contas_pagar` e `contas_receber`).
///
/// O campo [tipo] distingue despesa (`pagar`) de receita (`receber`). Os campos
/// específicos de cada tabela são anuláveis quando não se aplicam.
class ContaFinanceira {
  const ContaFinanceira({
    required this.id,
    required this.tipo,
    required this.descricao,
    required this.valor,
    required this.dataVencimento,
    this.status,
    this.categoriaId,
    this.centroCustoId,
    this.obraId,
    this.observacoes,
    this.numParcela,
    this.totalParcelas,
    // Pagar
    this.fornecedorId,
    this.dataPagamento,
    this.metodoPagamento,
    this.valorPago,
    // Receber
    this.cliente,
    this.clienteId,
    this.dataRecebimento,
    this.metodoRecebimento,
    this.valorRecebido,
    this.asaasPaymentId,
    this.asaasBillingType,
    this.asaasInvoiceUrl,
    this.asaasPixQrCode,
    this.asaasPixCopiaCola,
    this.asaasBoletoUrl,
    this.asaasLinhaDigitavel,
  });

  final String id;
  final String tipo; // 'pagar' | 'receber'
  final String descricao;
  final double valor;
  final String dataVencimento;
  final String? status;
  final String? categoriaId;
  final String? centroCustoId;
  final String? obraId;
  final String? observacoes;
  final int? numParcela;
  final int? totalParcelas;

  final String? fornecedorId;
  final String? dataPagamento;
  final String? metodoPagamento;
  final double? valorPago;

  final String? cliente;
  final String? clienteId;
  final String? dataRecebimento;
  final String? metodoRecebimento;
  final double? valorRecebido;
  final String? asaasPaymentId;
  final String? asaasBillingType;
  final String? asaasInvoiceUrl;
  final String? asaasPixQrCode;
  final String? asaasPixCopiaCola;
  final String? asaasBoletoUrl;
  final String? asaasLinhaDigitavel;

  bool get isPagar => tipo == 'pagar';
  bool get isReceber => tipo == 'receber';

  /// Valor já liquidado (pago ou recebido).
  double get liquidado =>
      isPagar ? (valorPago ?? 0) : (valorRecebido ?? 0);

  double get restante => (valor - liquidado).clamp(0, double.infinity);

  /// Status efetivo, aplicando a regra de vencido do webapp.
  String get statusEfetivo {
    final s = status ?? 'pendente';
    if ((s == 'pendente' || s == 'parcial') &&
        dataVencimento.isNotEmpty &&
        _hoje.compareTo(dataVencimento) > 0) {
      return 'vencido';
    }
    return s;
  }

  static String get _hoje {
    final now = DateTime.now();
    return '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }

  static double _d(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }

  factory ContaFinanceira.fromMap(Map<String, dynamic> map, String tipo) {
    return ContaFinanceira(
      id: map['id'] as String,
      tipo: tipo,
      descricao: (map['descricao'] as String?) ?? 'Conta',
      valor: _d(map['valor']),
      dataVencimento: (map['data_vencimento'] as String?) ?? '',
      status: map['status'] as String?,
      categoriaId: map['categoria_id'] as String?,
      centroCustoId: map['centro_custo_id'] as String?,
      obraId: map['obra_id'] as String?,
      observacoes: map['observacoes'] as String?,
      numParcela: (map['num_parcela'] as num?)?.toInt(),
      totalParcelas: (map['total_parcelas'] as num?)?.toInt(),
      fornecedorId: map['fornecedor_id'] as String?,
      dataPagamento: map['data_pagamento'] as String?,
      metodoPagamento: map['metodo_pagamento'] as String?,
      valorPago: map['valor_pago'] == null ? null : _d(map['valor_pago']),
      cliente: map['cliente'] as String?,
      clienteId: map['cliente_id'] as String?,
      dataRecebimento: map['data_recebimento'] as String?,
      metodoRecebimento: map['metodo_recebimento'] as String?,
      valorRecebido:
          map['valor_recebido'] == null ? null : _d(map['valor_recebido']),
      asaasPaymentId: map['asaas_payment_id'] as String?,
      asaasBillingType: map['asaas_billing_type'] as String?,
      asaasInvoiceUrl: map['asaas_invoice_url'] as String?,
      asaasPixQrCode: map['asaas_pix_qr_code'] as String?,
      asaasPixCopiaCola: map['asaas_pix_copia_cola'] as String?,
      asaasBoletoUrl: map['asaas_boleto_url'] as String?,
      asaasLinhaDigitavel: map['asaas_linha_digitavel'] as String?,
    );
  }
}
