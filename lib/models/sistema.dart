/// Modelos dos módulos de Sistema/Extras.
library;

class SupportTicket {
  const SupportTicket({
    required this.id,
    required this.assunto,
    this.descricao,
    this.categoria,
    this.prioridade = 'media',
    this.status = 'aberto',
    this.criadoPor,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String assunto;
  final String? descricao;
  final String? categoria;
  final String prioridade;
  final String status;
  final String? criadoPor;
  final String? createdAt;
  final String? updatedAt;

  factory SupportTicket.fromMap(Map<String, dynamic> m) => SupportTicket(
        id: m['id'] as String,
        assunto: (m['assunto'] as String?) ?? '',
        descricao: m['descricao'] as String?,
        categoria: m['categoria'] as String?,
        prioridade: (m['prioridade'] as String?) ?? 'media',
        status: (m['status'] as String?) ?? 'aberto',
        criadoPor: m['criado_por'] as String?,
        createdAt: m['created_at'] as String?,
        updatedAt: m['updated_at'] as String?,
      );
}

class SupportMessage {
  const SupportMessage({
    required this.id,
    required this.ticketId,
    required this.mensagem,
    this.autorNome,
    this.isSuperadmin = false,
    this.createdAt,
  });

  final String id;
  final String ticketId;
  final String mensagem;
  final String? autorNome;
  final bool isSuperadmin;
  final String? createdAt;

  factory SupportMessage.fromMap(Map<String, dynamic> m) => SupportMessage(
        id: m['id'] as String,
        ticketId: m['ticket_id'] as String,
        mensagem: (m['mensagem'] as String?) ?? '',
        autorNome: m['autor_nome'] as String?,
        isSuperadmin: (m['is_superadmin'] as bool?) ?? false,
        createdAt: m['created_at'] as String?,
      );
}

class FaturaSaas {
  const FaturaSaas({
    required this.id,
    required this.mes,
    required this.ano,
    required this.status,
    this.valorTotal = 0,
    this.valorBase = 0,
    this.valorFaixa = 0,
    this.planoNome,
    this.dataVencimento,
    this.dataPagamento,
    this.pagoEm,
    this.paymentUrl,
    this.pixCopiaCola,
    this.pixQrCode,
    this.notaFiscalUrl,
  });

  final String id;
  final int mes;
  final int ano;
  final String status;
  final double valorTotal;
  final double valorBase;
  final double valorFaixa;
  final String? planoNome;
  final String? dataVencimento;
  final String? dataPagamento;
  final String? pagoEm;
  final String? paymentUrl;
  final String? pixCopiaCola;
  final String? pixQrCode;
  final String? notaFiscalUrl;

  bool get paga => status == 'paga';

  static double _d(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }

  factory FaturaSaas.fromMap(Map<String, dynamic> m) => FaturaSaas(
        id: m['id'] as String,
        mes: (m['mes'] as num?)?.toInt() ?? 1,
        ano: (m['ano'] as num?)?.toInt() ?? DateTime.now().year,
        status: (m['status'] as String?) ?? 'pendente',
        valorTotal: _d(m['valor_total']),
        valorBase: _d(m['valor_base']),
        valorFaixa: _d(m['valor_faixa']),
        planoNome: m['plano_nome'] as String?,
        dataVencimento: m['data_vencimento'] as String?,
        dataPagamento: m['data_pagamento'] as String?,
        pagoEm: m['pago_em'] as String?,
        paymentUrl: m['payment_url'] as String?,
        pixCopiaCola: m['pix_copia_cola'] as String?,
        pixQrCode: m['pix_qr_code'] as String?,
        notaFiscalUrl: m['nota_fiscal_url'] as String?,
      );
}

class Orcamento {
  const Orcamento({
    required this.id,
    required this.cliente,
    required this.numeroOrcamento,
    this.status = 'rascunho',
    this.valorTotal,
    this.dataCriacao,
    this.dataValidade,
    this.endereco,
    this.contatoResponsavel,
    this.telefoneContato,
    this.metrosQuadrados,
    this.prazoEstimado,
    this.observacoes,
    this.linkPublicoAtivo = false,
    this.codigoPublico,
    this.percentualAjuste,
    this.bdiAtivo = false,
  });

  final String id;
  final String cliente;
  final int numeroOrcamento;
  final String status;
  final double? valorTotal;
  final String? dataCriacao;
  final String? dataValidade;
  final String? endereco;
  final String? contatoResponsavel;
  final String? telefoneContato;
  final double? metrosQuadrados;
  final String? prazoEstimado;
  final String? observacoes;
  final bool linkPublicoAtivo;
  final String? codigoPublico;
  final double? percentualAjuste;
  final bool bdiAtivo;

  static double? _dn(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  factory Orcamento.fromMap(Map<String, dynamic> m) => Orcamento(
        id: m['id'] as String,
        cliente: (m['cliente'] as String?) ?? '',
        numeroOrcamento: (m['numero_orcamento'] as num?)?.toInt() ?? 0,
        status: (m['status'] as String?) ?? 'rascunho',
        valorTotal: _dn(m['valor_total']),
        dataCriacao: m['data_criacao'] as String?,
        dataValidade: m['data_validade'] as String?,
        endereco: m['endereco'] as String?,
        contatoResponsavel: m['contato_responsavel'] as String?,
        telefoneContato: m['telefone_contato'] as String?,
        metrosQuadrados: _dn(m['metros_quadrados']),
        prazoEstimado: m['prazo_estimado'] as String?,
        observacoes: m['observacoes'] as String?,
        linkPublicoAtivo: (m['link_publico_ativo'] as bool?) ?? false,
        codigoPublico: m['codigo_publico'] as String?,
        percentualAjuste: _dn(m['percentual_ajuste']),
        bdiAtivo: (m['bdi_ativo'] as bool?) ?? false,
      );
}
