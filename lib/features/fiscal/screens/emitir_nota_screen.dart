import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../providers/cadastros_providers.dart';
import '../../../providers/fiscal_providers.dart';
import '../../../providers/supabase_providers.dart';

class _ItemForm {
  _ItemForm()
      : descricao = TextEditingController(),
        quantidade = TextEditingController(text: '1'),
        valorUnitario = TextEditingController(),
        ncm = TextEditingController(),
        cfop = TextEditingController(),
        unidade = TextEditingController(text: 'UN'),
        aliquotaIcms = TextEditingController(),
        aliquotaIpi = TextEditingController(),
        aliquotaPis = TextEditingController(),
        aliquotaCofins = TextEditingController();

  final TextEditingController descricao;
  final TextEditingController quantidade;
  final TextEditingController valorUnitario;
  final TextEditingController ncm;
  final TextEditingController cfop;
  final TextEditingController unidade;
  final TextEditingController aliquotaIcms;
  final TextEditingController aliquotaIpi;
  final TextEditingController aliquotaPis;
  final TextEditingController aliquotaCofins;

  void dispose() {
    for (final c in [
      descricao,
      quantidade,
      valorUnitario,
      ncm,
      cfop,
      unidade,
      aliquotaIcms,
      aliquotaIpi,
      aliquotaPis,
      aliquotaCofins,
    ]) {
      c.dispose();
    }
  }

  double get total =>
      (double.tryParse(quantidade.text.replaceAll(',', '.')) ?? 0) *
      (double.tryParse(valorUnitario.text.replaceAll(',', '.')) ?? 0);
}

const _formas = [
  ('01', 'Dinheiro'),
  ('03', 'Cartão de crédito'),
  ('04', 'Cartão de débito'),
  ('15', 'Boleto'),
  ('17', 'PIX'),
  ('99', 'Outros'),
];

const _finalidades = [
  (1, 'Normal'),
  (2, 'Complementar'),
  (3, 'Ajuste'),
  (4, 'Devolução'),
];

const _presencas = [
  (0, 'Não se aplica'),
  (1, 'Presencial'),
  (2, 'Internet'),
  (3, 'Teleatendimento'),
  (9, 'Não presencial (outros)'),
];

const _tiposOperacao = [
  (1, 'Saída'),
  (0, 'Entrada'),
];

const _modalidadesFrete = [
  (9, 'Sem frete'),
  (0, 'CIF (por conta do emitente)'),
  (1, 'FOB (por conta do destinatário)'),
  (2, 'Por conta de terceiros'),
  (3, 'Próprio, por conta do remetente'),
  (4, 'Próprio, por conta do destinatário'),
];

/// Tela de emissão de nota fiscal (rascunho + emissão), com transporte,
/// volumes, impostos por item e dados da operação.
class EmitirNotaScreen extends ConsumerStatefulWidget {
  const EmitirNotaScreen({super.key});

  @override
  ConsumerState<EmitirNotaScreen> createState() => _EmitirNotaScreenState();
}

class _EmitirNotaScreenState extends ConsumerState<EmitirNotaScreen> {
  String? _clienteId;
  final _natureza = TextEditingController(text: 'Venda de mercadoria');
  final _observacoes = TextEditingController();
  final _condicaoPagamento = TextEditingController();
  final _valorFrete = TextEditingController();
  String _formaPagamento = '01';
  int _finalidade = 1;
  int _presenca = 9;
  int _tipoOperacao = 1;
  int _modalidadeFrete = 9;

  final _transpNome = TextEditingController();
  final _transpCnpj = TextEditingController();
  final _transpIe = TextEditingController();
  final _transpEndereco = TextEditingController();
  final _transpMunicipio = TextEditingController();
  final _transpUf = TextEditingController();
  final _veiculoPlaca = TextEditingController();
  final _veiculoUf = TextEditingController();
  final _veiculoRntc = TextEditingController();
  final _volumesQtd = TextEditingController();
  final _volumesEspecie = TextEditingController();
  final _volumesMarca = TextEditingController();
  final _volumesNumeracao = TextEditingController();
  final _pesoLiquido = TextEditingController();
  final _pesoBruto = TextEditingController();

  final List<_ItemForm> _itens = [_ItemForm()];
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [
      _natureza,
      _observacoes,
      _condicaoPagamento,
      _valorFrete,
      _transpNome,
      _transpCnpj,
      _transpIe,
      _transpEndereco,
      _transpMunicipio,
      _transpUf,
      _veiculoPlaca,
      _veiculoUf,
      _veiculoRntc,
      _volumesQtd,
      _volumesEspecie,
      _volumesMarca,
      _volumesNumeracao,
      _pesoLiquido,
      _pesoBruto,
    ]) {
      c.dispose();
    }
    for (final i in _itens) {
      i.dispose();
    }
    super.dispose();
  }

  double get _totalItens => _itens.fold(0, (s, i) => s + i.total);

  double _num(TextEditingController c) =>
      double.tryParse(c.text.replaceAll(',', '.')) ?? 0;

  String? _nz(TextEditingController c) =>
      c.text.trim().isEmpty ? null : c.text.trim();

  List<Map<String, dynamic>> _buildItens() {
    return _itens
        .where((i) => i.descricao.text.trim().isNotEmpty)
        .toList()
        .asMap()
        .entries
        .map((e) {
          final it = e.value;
          double? pct(TextEditingController c) =>
              c.text.trim().isEmpty ? null : _num(c);
          return {
            'descricao': it.descricao.text.trim(),
            'quantidade': _num(it.quantidade),
            'valor_unitario': _num(it.valorUnitario),
            'valor_total': it.total,
            'ncm': _nz(it.ncm),
            'cfop': _nz(it.cfop),
            'unidade': it.unidade.text.trim().isEmpty
                ? 'UN'
                : it.unidade.text.trim(),
            'aliquota_icms': pct(it.aliquotaIcms),
            'aliquota_ipi': pct(it.aliquotaIpi),
            'aliquota_pis': pct(it.aliquotaPis),
            'aliquota_cofins': pct(it.aliquotaCofins),
            'ordem': e.key + 1,
          };
        })
        .toList();
  }

  Future<void> _salvar({required bool emitir}) async {
    if (_clienteId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione o cliente')),
      );
      return;
    }
    final itens = _buildItens();
    if (itens.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Adicione ao menos um item')),
      );
      return;
    }
    setState(() => _saving = true);
    final frete = _num(_valorFrete);
    final nota = <String, dynamic>{
      'cliente_id': _clienteId,
      'natureza_operacao': _natureza.text.trim(),
      'forma_pagamento': _formaPagamento,
      'condicao_pagamento': _nz(_condicaoPagamento),
      'observacoes': _nz(_observacoes),
      'valor_produtos': _totalItens,
      'valor_frete': frete,
      'valor_total': _totalItens + frete,
      'valor_pagamento': _totalItens + frete,
      'tipo_documento': 'nfe',
      'tipo_operacao': _tipoOperacao,
      'finalidade': _finalidade,
      'indicador_presenca': _presenca,
      'modalidade_frete': _modalidadeFrete,
      'transportador_nome': _nz(_transpNome),
      'transportador_cnpj_cpf': _nz(_transpCnpj),
      'transportador_ie': _nz(_transpIe),
      'transportador_endereco': _nz(_transpEndereco),
      'transportador_municipio': _nz(_transpMunicipio),
      'transportador_uf': _nz(_transpUf),
      'veiculo_placa': _nz(_veiculoPlaca),
      'veiculo_uf': _nz(_veiculoUf),
      'veiculo_rntc': _nz(_veiculoRntc),
      'volumes_qtd':
          _volumesQtd.text.trim().isEmpty ? null : int.tryParse(_volumesQtd.text),
      'volumes_especie': _nz(_volumesEspecie),
      'volumes_marca': _nz(_volumesMarca),
      'volumes_numeracao': _nz(_volumesNumeracao),
      'peso_liquido': _pesoLiquido.text.trim().isEmpty ? null : _num(_pesoLiquido),
      'peso_bruto': _pesoBruto.text.trim().isEmpty ? null : _num(_pesoBruto),
    };
    try {
      final repo = ref.read(fiscalRepositoryProvider);
      final notaId = await repo.criarNotaRascunho(nota, itens);
      if (emitir) {
        await repo.acaoNfe('emitir', {'nota_id': notaId});
      }
      ref.invalidate(notasFiscaisProvider);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'.replaceFirst('Exception: ', ''))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final clientesAsync = ref.watch(clientesListProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Emitir Nota')),
      body: clientesAsync.when(
        loading: () => const LoadingView(),
        error: (e, _) => Center(child: Text('Erro: $e')),
        data: (clientes) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            children: [
              DropdownButtonFormField<String>(
                initialValue: _clienteId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Cliente *'),
                items: clientes
                    .where((c) => c.ativo)
                    .map((c) => DropdownMenuItem(
                          value: c.id,
                          child: Text(c.nome, overflow: TextOverflow.ellipsis),
                        ))
                    .toList(),
                onChanged:
                    _saving ? null : (v) => setState(() => _clienteId = v),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _natureza,
                enabled: !_saving,
                decoration:
                    const InputDecoration(labelText: 'Natureza da operação'),
              ),
              const SizedBox(height: 12),
              _dropdownInt('Tipo de operação', _tiposOperacao, _tipoOperacao,
                  (v) => setState(() => _tipoOperacao = v)),
              const SizedBox(height: 12),
              _dropdownInt('Finalidade', _finalidades, _finalidade,
                  (v) => setState(() => _finalidade = v)),
              const SizedBox(height: 12),
              _dropdownInt('Presença do comprador', _presencas, _presenca,
                  (v) => setState(() => _presenca = v)),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _formaPagamento,
                decoration:
                    const InputDecoration(labelText: 'Forma de pagamento'),
                items: _formas
                    .map((f) => DropdownMenuItem(
                          value: f.$1,
                          child: Text(f.$2),
                        ))
                    .toList(),
                onChanged: _saving
                    ? null
                    : (v) => setState(() => _formaPagamento = v ?? '01'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _condicaoPagamento,
                enabled: !_saving,
                decoration: const InputDecoration(
                    labelText: 'Condição de pagamento',
                    hintText: 'Ex: 30/60/90 dias'),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  const Text('Itens',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: _saving
                        ? null
                        : () => setState(() => _itens.add(_ItemForm())),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Adicionar'),
                  ),
                ],
              ),
              ..._itens.asMap().entries.map((entry) {
                final idx = entry.key;
                final item = entry.value;
                return _itemCard(idx, item);
              }),
              const SizedBox(height: 8),
              ExpansionTile(
                title: const Text('Transporte, veículo e volumes',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                tilePadding: EdgeInsets.zero,
                childrenPadding: const EdgeInsets.only(bottom: 12),
                children: [
                  _dropdownInt('Modalidade de frete', _modalidadesFrete,
                      _modalidadeFrete,
                      (v) => setState(() => _modalidadeFrete = v)),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _valorFrete,
                    enabled: !_saving,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => setState(() {}),
                    decoration:
                        const InputDecoration(labelText: 'Valor do frete (R\$)'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _transpNome,
                    enabled: !_saving,
                    decoration:
                        const InputDecoration(labelText: 'Transportador'),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _transpCnpj,
                          enabled: !_saving,
                          decoration: const InputDecoration(
                              labelText: 'CNPJ/CPF', isDense: true),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _transpIe,
                          enabled: !_saving,
                          decoration: const InputDecoration(
                              labelText: 'Insc. estadual', isDense: true),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _transpEndereco,
                    enabled: !_saving,
                    decoration:
                        const InputDecoration(labelText: 'Endereço'),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _transpMunicipio,
                          enabled: !_saving,
                          decoration: const InputDecoration(
                              labelText: 'Município', isDense: true),
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 80,
                        child: TextField(
                          controller: _transpUf,
                          enabled: !_saving,
                          maxLength: 2,
                          decoration: const InputDecoration(
                              labelText: 'UF',
                              isDense: true,
                              counterText: ''),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _veiculoPlaca,
                          enabled: !_saving,
                          decoration: const InputDecoration(
                              labelText: 'Placa', isDense: true),
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 80,
                        child: TextField(
                          controller: _veiculoUf,
                          enabled: !_saving,
                          maxLength: 2,
                          decoration: const InputDecoration(
                              labelText: 'UF',
                              isDense: true,
                              counterText: ''),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _veiculoRntc,
                          enabled: !_saving,
                          decoration: const InputDecoration(
                              labelText: 'RNTC', isDense: true),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _volumesQtd,
                          enabled: !_saving,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                              labelText: 'Qtd. volumes', isDense: true),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _volumesEspecie,
                          enabled: !_saving,
                          decoration: const InputDecoration(
                              labelText: 'Espécie', isDense: true),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _volumesMarca,
                          enabled: !_saving,
                          decoration: const InputDecoration(
                              labelText: 'Marca', isDense: true),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _volumesNumeracao,
                          enabled: !_saving,
                          decoration: const InputDecoration(
                              labelText: 'Numeração', isDense: true),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _pesoLiquido,
                          enabled: !_saving,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          decoration: const InputDecoration(
                              labelText: 'Peso líquido (kg)', isDense: true),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _pesoBruto,
                          enabled: !_saving,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          decoration: const InputDecoration(
                              labelText: 'Peso bruto (kg)', isDense: true),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _observacoes,
                enabled: !_saving,
                maxLines: 2,
                decoration:
                    const InputDecoration(labelText: 'Observações'),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.muted,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total (produtos + frete)',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    Text(
                      'R\$ ${(_totalItens + _num(_valorFrete)).toStringAsFixed(2)}',
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 16),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _saving ? null : () => _salvar(emitir: true),
                child: Text(_saving ? 'Processando...' : 'Emitir nota'),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: _saving ? null : () => _salvar(emitir: false),
                child: const Text('Salvar rascunho'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _dropdownInt(
    String label,
    List<(int, String)> options,
    int value,
    ValueChanged<int> onChanged,
  ) {
    return DropdownButtonFormField<int>(
      initialValue: value,
      decoration: InputDecoration(labelText: label),
      items: options
          .map((o) => DropdownMenuItem(value: o.$1, child: Text(o.$2)))
          .toList(),
      onChanged: _saving ? null : (v) => onChanged(v ?? value),
    );
  }

  Widget _itemCard(int idx, _ItemForm item) {
    Widget pctField(TextEditingController c, String label) => TextField(
          controller: c,
          enabled: !_saving,
          keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(labelText: label, isDense: true),
        );

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: item.descricao,
                    enabled: !_saving,
                    decoration: const InputDecoration(
                        labelText: 'Descrição', isDense: true),
                  ),
                ),
                if (_itens.length > 1)
                  IconButton(
                    icon: const Icon(Icons.delete_outline,
                        size: 20, color: AppColors.destructive),
                    onPressed: _saving
                        ? null
                        : () => setState(() {
                              item.dispose();
                              _itens.removeAt(idx);
                            }),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: item.quantidade,
                    enabled: !_saving,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                        labelText: 'Qtd', isDense: true),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: item.unidade,
                    enabled: !_saving,
                    decoration: const InputDecoration(
                        labelText: 'Un', isDense: true),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: item.valorUnitario,
                    enabled: !_saving,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                        labelText: 'V. unit.', isDense: true),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: item.ncm,
                    enabled: !_saving,
                    decoration: const InputDecoration(
                        labelText: 'NCM', isDense: true),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: item.cfop,
                    enabled: !_saving,
                    decoration: const InputDecoration(
                        labelText: 'CFOP', isDense: true),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'R\$ ${item.total.toStringAsFixed(2)}',
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 12.5),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: pctField(item.aliquotaIcms, 'ICMS %')),
                const SizedBox(width: 8),
                Expanded(child: pctField(item.aliquotaIpi, 'IPI %')),
                const SizedBox(width: 8),
                Expanded(child: pctField(item.aliquotaPis, 'PIS %')),
                const SizedBox(width: 8),
                Expanded(child: pctField(item.aliquotaCofins, 'COFINS %')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
