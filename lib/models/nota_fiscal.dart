/// Modelos do módulo Fiscal.
class NotaFiscal {
  const NotaFiscal({
    required this.id,
    required this.status,
    this.numero,
    this.serie,
    this.tipoDocumento = 'nfe',
    this.ambiente = 'homologacao',
    this.clienteId,
    this.clienteNome,
    this.clienteEmail,
    this.clienteCpfCnpj,
    this.chaveAcesso,
    this.protocolo,
    this.dataEmissao,
    this.naturezaOperacao,
    this.mensagemSefaz,
    this.valorTotal,
    this.valorProdutos,
    this.valorFrete,
    this.valorDesconto,
    this.danfeUrl,
    this.xmlUrl,
    this.contaReceberId,
    this.formaPagamento,
    this.observacoes,
  });

  final String id;
  final String status;
  final int? numero;
  final int? serie;
  final String tipoDocumento;
  final String ambiente;
  final String? clienteId;
  final String? clienteNome;
  final String? clienteEmail;
  final String? clienteCpfCnpj;
  final String? chaveAcesso;
  final String? protocolo;
  final String? dataEmissao;
  final String? naturezaOperacao;
  final String? mensagemSefaz;
  final double? valorTotal;
  final double? valorProdutos;
  final double? valorFrete;
  final double? valorDesconto;
  final String? danfeUrl;
  final String? xmlUrl;
  final String? contaReceberId;
  final String? formaPagamento;
  final String? observacoes;

  static double? _dn(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  factory NotaFiscal.fromMap(Map<String, dynamic> m) {
    final cli = m['clientes'];
    String? cliNome, cliEmail, cliDoc;
    if (cli is Map) {
      cliNome = cli['nome'] as String?;
      cliEmail = cli['email'] as String?;
      cliDoc = cli['cpf_cnpj'] as String?;
    }
    return NotaFiscal(
      id: m['id'] as String,
      status: (m['status'] as String?) ?? 'rascunho',
      numero: (m['numero'] as num?)?.toInt(),
      serie: (m['serie'] as num?)?.toInt(),
      tipoDocumento: (m['tipo_documento'] as String?) ?? 'nfe',
      ambiente: (m['ambiente'] as String?) ?? 'homologacao',
      clienteId: m['cliente_id'] as String?,
      clienteNome: cliNome,
      clienteEmail: cliEmail,
      clienteCpfCnpj: cliDoc,
      chaveAcesso: m['chave_acesso'] as String?,
      protocolo: m['protocolo'] as String?,
      dataEmissao: m['data_emissao'] as String?,
      naturezaOperacao: m['natureza_operacao'] as String?,
      mensagemSefaz: m['mensagem_sefaz'] as String?,
      valorTotal: _dn(m['valor_total']),
      valorProdutos: _dn(m['valor_produtos']),
      valorFrete: _dn(m['valor_frete']),
      valorDesconto: _dn(m['valor_desconto']),
      danfeUrl: m['danfe_url'] as String?,
      xmlUrl: m['xml_url'] as String?,
      contaReceberId: m['conta_receber_id'] as String?,
      formaPagamento: m['forma_pagamento'] as String?,
      observacoes: m['observacoes'] as String?,
    );
  }
}

class NotaFiscalItem {
  const NotaFiscalItem({
    required this.id,
    required this.descricao,
    this.ncm,
    this.cfop,
    this.quantidade,
    this.unidade,
    this.valorUnitario,
    this.valorTotal,
  });

  final String id;
  final String descricao;
  final String? ncm;
  final String? cfop;
  final double? quantidade;
  final String? unidade;
  final double? valorUnitario;
  final double? valorTotal;

  static double? _dn(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  factory NotaFiscalItem.fromMap(Map<String, dynamic> m) => NotaFiscalItem(
        id: m['id'] as String,
        descricao: (m['descricao'] as String?) ?? '',
        ncm: m['ncm'] as String?,
        cfop: m['cfop'] as String?,
        quantidade: _dn(m['quantidade']),
        unidade: m['unidade'] as String?,
        valorUnitario: _dn(m['valor_unitario']),
        valorTotal: _dn(m['valor_total']),
      );
}

class NotaFiscalRecebida {
  const NotaFiscalRecebida({
    required this.id,
    required this.chaveNfe,
    this.emitenteNome,
    this.emitenteCnpj,
    this.numero,
    this.serie,
    this.dataEmissao,
    this.valorTotal,
    this.status,
    this.manifestoStatus,
    this.xmlUrl,
    this.danfeUrl,
  });

  final String id;
  final String chaveNfe;
  final String? emitenteNome;
  final String? emitenteCnpj;
  final String? numero;
  final String? serie;
  final String? dataEmissao;
  final double? valorTotal;
  final String? status;
  final String? manifestoStatus;
  final String? xmlUrl;
  final String? danfeUrl;

  static double? _dn(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  factory NotaFiscalRecebida.fromMap(Map<String, dynamic> m) =>
      NotaFiscalRecebida(
        id: m['id'] as String,
        chaveNfe: (m['chave_nfe'] as String?) ?? '',
        emitenteNome: m['emitente_nome'] as String?,
        emitenteCnpj: m['emitente_cnpj'] as String?,
        numero: m['numero'] as String?,
        serie: m['serie'] as String?,
        dataEmissao: m['data_emissao'] as String?,
        valorTotal: _dn(m['valor_total']),
        status: m['status'] as String?,
        manifestoStatus: m['manifesto_status'] as String?,
        xmlUrl: m['xml_url'] as String?,
        danfeUrl: m['danfe_url'] as String?,
      );
}
