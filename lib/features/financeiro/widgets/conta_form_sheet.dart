import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../models/conta_financeira.dart';
import '../../../providers/cadastros_providers.dart';
import '../../../providers/financeiro_providers.dart';
import '../../../providers/auth_providers.dart';
import '../../../providers/supabase_providers.dart';

/// Abre o formulário de conta a pagar/receber. Retorna `true` se salvou.
Future<bool?> showContaFormSheet(
  BuildContext context, {
  required String tipo,
  ContaFinanceira? conta,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _ContaFormSheet(tipo: tipo, conta: conta),
  );
}

class _ContaFormSheet extends ConsumerStatefulWidget {
  const _ContaFormSheet({required this.tipo, this.conta});

  final String tipo;
  final ContaFinanceira? conta;

  @override
  ConsumerState<_ContaFormSheet> createState() => _ContaFormSheetState();
}

class _ContaFormSheetState extends ConsumerState<_ContaFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _descricao;
  late final TextEditingController _valor;
  late final TextEditingController _observacoes;
  late final TextEditingController _clienteLivre;

  String? _categoriaId;
  String? _centroId;
  String? _fornecedorId;
  String? _clienteId;
  String? _obraId;
  DateTime? _vencimento;
  bool _parcelar = false;
  final _parcelas = TextEditingController(text: '2');
  bool _saving = false;

  bool get _isEdit => widget.conta != null;
  bool get _isPagar => widget.tipo == 'pagar';

  @override
  void initState() {
    super.initState();
    final c = widget.conta;
    _descricao = TextEditingController(text: c?.descricao ?? '');
    _valor = TextEditingController(
      text: c != null ? c.valor.toStringAsFixed(2) : '',
    );
    _observacoes = TextEditingController(text: c?.observacoes ?? '');
    _clienteLivre = TextEditingController(text: c?.cliente ?? '');
    _categoriaId = c?.categoriaId;
    _centroId = c?.centroCustoId;
    _fornecedorId = c?.fornecedorId;
    _clienteId = c?.clienteId;
    _obraId = c?.obraId;
    _vencimento = c != null ? DateTime.tryParse(c.dataVencimento) : null;
  }

  @override
  void dispose() {
    _descricao.dispose();
    _valor.dispose();
    _observacoes.dispose();
    _clienteLivre.dispose();
    _parcelas.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;
    if (_vencimento == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe a data de vencimento')),
      );
      return;
    }
    final valor = double.tryParse(_valor.text.replaceAll(',', '.'));
    if (valor == null || valor <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Valor inválido')),
      );
      return;
    }

    setState(() => _saving = true);
    final repo = ref.read(financeiroRepositoryProvider);
    final dataVenc = Formatters.iso(_vencimento!);
    final base = <String, dynamic>{
      'descricao': _descricao.text.trim(),
      'valor': valor,
      'data_vencimento': dataVenc,
      'categoria_id': _categoriaId,
      'centro_custo_id': _centroId,
      'obra_id': _obraId,
      'observacoes': _observacoes.text.trim().isEmpty
          ? null
          : _observacoes.text.trim(),
    };

    try {
      if (_isEdit) {
        await repo.updateConta(widget.tipo, widget.conta!.id, {
          ...base,
          if (_isPagar) 'fornecedor_id': _fornecedorId,
          if (!_isPagar) 'fornecedor_id': null,
          if (!_isPagar) 'cliente_id': _clienteId,
          if (!_isPagar)
            'cliente': _clienteLivre.text.trim().isEmpty
                ? null
                : _clienteLivre.text.trim(),
        });
      } else if (_parcelar) {
        final n = int.tryParse(_parcelas.text) ?? 2;
        final nClamped = n.clamp(2, 120);
        final valorParcela = (valor / nClamped * 100).round() / 100;
        final grupo = DateTime.now().microsecondsSinceEpoch.toString();
        final parcelas = <Map<String, dynamic>>[];
        for (var i = 0; i < nClamped; i++) {
          final dt = DateTime(
            _vencimento!.year,
            _vencimento!.month + i,
            _vencimento!.day,
          );
          final v = i == nClamped - 1
              ? ((valor - valorParcela * (nClamped - 1)) * 100).round() / 100
              : valorParcela;
          parcelas.add({
            ...base,
            'descricao':
                '${_descricao.text.trim()} (${i + 1}/$nClamped)',
            'valor': v,
            'data_vencimento': Formatters.iso(dt),
            'parcela_grupo_id': grupo,
            'num_parcela': i + 1,
            'total_parcelas': nClamped,
            if (_isPagar) 'fornecedor_id': _fornecedorId,
            if (!_isPagar) 'cliente_id': _clienteId,
            if (!_isPagar)
              'cliente': _clienteLivre.text.trim().isEmpty
                  ? null
                  : _clienteLivre.text.trim(),
          });
        }
        await repo.createParcelas(widget.tipo, parcelas);
      } else {
        await repo.createConta(widget.tipo, {
          ...base,
          if (_isPagar) 'fornecedor_id': _fornecedorId,
          if (!_isPagar) 'cliente_id': _clienteId,
          if (!_isPagar)
            'cliente': _clienteLivre.text.trim().isEmpty
                ? null
                : _clienteLivre.text.trim(),
        });
      }
      _invalidar();
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erro: $e')));
      }
    }
  }

  void _invalidar() {
    if (_isPagar) {
      ref.invalidate(contasPagarListProvider);
    } else {
      ref.invalidate(contasReceberListProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final categorias = ref.watch(categoriasFinanceirasListProvider).value ?? [];
    final centros = ref.watch(centrosCustoListProvider).value ?? [];
    final fornecedores = ref.watch(fornecedoresListProvider).value ?? [];
    final clientes = ref.watch(clientesListProvider).value ?? [];
    final obras = ref.watch(obrasListProvider).value ?? [];

    final catsFiltradas = categorias.where((c) {
      if (!c.ativa) return false;
      return c.tipo == 'ambos' ||
          (_isPagar ? c.tipo == 'despesa' : c.tipo == 'receita');
    }).toList();

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        20 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Text(
                    _isEdit
                        ? 'Editar Conta'
                        : _isPagar
                            ? 'Nova Conta a Pagar'
                            : 'Nova Conta a Receber',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _descricao,
                enabled: !_saving,
                decoration: const InputDecoration(labelText: 'Descrição *'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Informe a descrição' : null,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _valor,
                      enabled: !_saving,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      decoration: const InputDecoration(labelText: 'Valor (R\$) *'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: InkWell(
                      onTap: _saving
                          ? null
                          : () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: _vencimento ?? DateTime.now(),
                                firstDate: DateTime(2000),
                                lastDate: DateTime(2100),
                              );
                              if (picked != null) {
                                setState(() => _vencimento = picked);
                              }
                            },
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Vencimento *',
                          suffixIcon: Icon(Icons.calendar_today_outlined,
                              size: 18),
                        ),
                        child: Text(_vencimento != null
                            ? Formatters.dataBr(_vencimento)
                            : 'Selecionar'),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _categoriaId,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Categoria'),
                      items: catsFiltradas
                          .map((c) => DropdownMenuItem(
                                value: c.id,
                                child: Text(c.nome,
                                    overflow: TextOverflow.ellipsis),
                              ))
                          .toList(),
                      onChanged: _saving
                          ? null
                          : (v) => setState(() => _categoriaId = v),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _centroId,
                      isExpanded: true,
                      decoration:
                          const InputDecoration(labelText: 'Centro de custo'),
                      items: centros
                          .where((c) => c.ativo)
                          .map((c) => DropdownMenuItem(
                                value: c.id,
                                child: Text(c.nome,
                                    overflow: TextOverflow.ellipsis),
                              ))
                          .toList(),
                      onChanged: _saving
                          ? null
                          : (v) => setState(() => _centroId = v),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (_isPagar)
                DropdownButtonFormField<String>(
                  initialValue: _fornecedorId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Fornecedor'),
                  items: fornecedores
                      .where((f) => f.ativo)
                      .map((f) => DropdownMenuItem(
                            value: f.id,
                            child: Text(f.nomeFantasia ?? f.razaoSocial,
                                overflow: TextOverflow.ellipsis),
                          ))
                      .toList(),
                  onChanged:
                      _saving ? null : (v) => setState(() => _fornecedorId = v),
                )
              else ...[
                DropdownButtonFormField<String>(
                  initialValue: _clienteId,
                  isExpanded: true,
                  decoration:
                      const InputDecoration(labelText: 'Cliente (cadastrado)'),
                  items: clientes
                      .where((c) => c.ativo)
                      .map((c) => DropdownMenuItem(
                            value: c.id,
                            child: Text(c.nome, overflow: TextOverflow.ellipsis),
                          ))
                      .toList(),
                  onChanged: _saving
                      ? null
                      : (v) {
                          final cli = clientes.where((c) => c.id == v).firstOrNull;
                          setState(() {
                            _clienteId = v;
                            if (cli != null) _clienteLivre.text = cli.nome;
                          });
                        },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _clienteLivre,
                  enabled: !_saving,
                  decoration: const InputDecoration(
                      labelText: 'Cliente (texto livre)'),
                ),
              ],
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _obraId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Obra'),
                items: obras
                    .map((o) => DropdownMenuItem(
                          value: o.id,
                          child: Text(o.nome, overflow: TextOverflow.ellipsis),
                        ))
                    .toList(),
                onChanged: _saving ? null : (v) => setState(() => _obraId = v),
              ),
              if (!_isEdit) ...[
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Parcelar'),
                  value: _parcelar,
                  onChanged:
                      _saving ? null : (v) => setState(() => _parcelar = v),
                ),
                if (_parcelar)
                  TextFormField(
                    controller: _parcelas,
                    enabled: !_saving,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                        labelText: 'Número de parcelas'),
                  ),
              ],
              const SizedBox(height: 12),
              TextFormField(
                controller: _observacoes,
                enabled: !_saving,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Observações'),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _saving ? null : _salvar,
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.4, color: Colors.white),
                      )
                    : Text(_isEdit
                        ? 'Salvar'
                        : _parcelar
                            ? 'Criar parcelas'
                            : 'Cadastrar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
