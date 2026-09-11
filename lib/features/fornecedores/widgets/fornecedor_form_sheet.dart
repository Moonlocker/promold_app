import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/cep.dart';
import '../../../core/utils/masks.dart';
import '../../../models/fornecedor.dart';
import '../../../providers/cadastros_providers.dart';
import '../../../providers/supabase_providers.dart';

/// Abre o formulário de fornecedor. Retorna `true` se salvou.
Future<bool?> showFornecedorFormSheet(
  BuildContext context, {
  Fornecedor? fornecedor,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _FornecedorFormSheet(fornecedor: fornecedor),
  );
}

class _FornecedorFormSheet extends ConsumerStatefulWidget {
  const _FornecedorFormSheet({this.fornecedor});

  final Fornecedor? fornecedor;

  @override
  ConsumerState<_FornecedorFormSheet> createState() =>
      _FornecedorFormSheetState();
}

class _FornecedorFormSheetState extends ConsumerState<_FornecedorFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final Map<String, TextEditingController> _c;
  String _tipoPessoa = 'pj';
  bool _saving = false;

  bool get _isEdit => widget.fornecedor != null;

  @override
  void initState() {
    super.initState();
    final f = widget.fornecedor;
    _tipoPessoa = f?.tipoPessoa ?? 'pj';
    _c = {
      'razao_social': TextEditingController(text: f?.razaoSocial ?? ''),
      'nome_fantasia': TextEditingController(text: f?.nomeFantasia ?? ''),
      'cnpj_cpf': TextEditingController(text: f?.cnpjCpf ?? ''),
      'telefone1': TextEditingController(text: f?.telefone1 ?? ''),
      'telefone2': TextEditingController(text: f?.telefone2 ?? ''),
      'email': TextEditingController(text: f?.email ?? ''),
      'responsavel': TextEditingController(text: f?.responsavel ?? ''),
      'cep': TextEditingController(text: f?.cep ?? ''),
      'endereco': TextEditingController(text: f?.endereco ?? ''),
      'cidade': TextEditingController(text: f?.cidade ?? ''),
      'estado': TextEditingController(text: f?.estado ?? ''),
      'observacoes': TextEditingController(text: f?.observacoes ?? ''),
    };
  }

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }

  String? _nz(String key) {
    final v = _c[key]!.text.trim();
    return v.isEmpty ? null : v;
  }

  Future<void> _buscarCep() async {
    final info = await buscarCep(_c['cep']!.text);
    if (info == null || !mounted) return;
    setState(() {
      if (info.logradouro != null) _c['endereco']!.text = info.logradouro!;
      if (info.cidade != null) _c['cidade']!.text = info.cidade!;
      if (info.uf != null) _c['estado']!.text = info.uf!;
    });
  }

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final payload = <String, dynamic>{
      'razao_social': _c['razao_social']!.text.trim(),
      'nome_fantasia': _nz('nome_fantasia'),
      'tipo_pessoa': _tipoPessoa,
      'cnpj_cpf': _nz('cnpj_cpf'),
      'telefone1': _nz('telefone1'),
      'telefone2': _nz('telefone2'),
      'email': _nz('email'),
      'responsavel': _nz('responsavel'),
      'cep': _nz('cep'),
      'endereco': _nz('endereco'),
      'cidade': _nz('cidade'),
      'estado': _nz('estado'),
      'observacoes': _nz('observacoes'),
    };
    try {
      final repo = ref.read(fornecedoresRepositoryProvider);
      if (_isEdit) {
        await repo.update(widget.fornecedor!.id, payload);
      } else {
        await repo.create(payload);
      }
      ref.invalidate(fornecedoresListProvider);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erro: $e')));
      }
    }
  }

  void _mask(String key, String value, String Function(String) fn) {
    final m = fn(value);
    _c[key]!.value = TextEditingValue(
      text: m,
      selection: TextSelection.collapsed(offset: m.length),
    );
  }

  @override
  Widget build(BuildContext context) {
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
                    _isEdit ? 'Editar Fornecedor' : 'Novo Fornecedor',
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
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _tipoPessoa,
                      decoration: const InputDecoration(labelText: 'Tipo'),
                      items: const [
                        DropdownMenuItem(
                            value: 'pj', child: Text('Pessoa Jurídica')),
                        DropdownMenuItem(
                            value: 'pf', child: Text('Pessoa Física')),
                      ],
                      onChanged: _saving
                          ? null
                          : (v) => setState(() => _tipoPessoa = v ?? 'pj'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _c['cnpj_cpf'],
                      enabled: !_saving,
                      decoration: InputDecoration(
                        labelText: _tipoPessoa == 'pf' ? 'CPF' : 'CNPJ',
                      ),
                      onChanged: (v) {
                        final d = Masks.onlyDigits(v);
                        _mask(
                          'cnpj_cpf',
                          v,
                          (_) => _tipoPessoa == 'pf'
                              ? Masks.maskCPF(d)
                              : Masks.maskCNPJ(d),
                        );
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _c['razao_social'],
                enabled: !_saving,
                decoration: const InputDecoration(labelText: 'Razão Social *'),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Informe a razão social'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _c['nome_fantasia'],
                enabled: !_saving,
                decoration: const InputDecoration(labelText: 'Nome Fantasia'),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _c['telefone1'],
                      enabled: !_saving,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(labelText: 'Telefone 1'),
                      onChanged: (v) => _mask('telefone1', v, Masks.maskPhone),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _c['telefone2'],
                      enabled: !_saving,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(labelText: 'Telefone 2'),
                      onChanged: (v) => _mask('telefone2', v, Masks.maskPhone),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _c['email'],
                enabled: !_saving,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'E-mail'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _c['responsavel'],
                enabled: !_saving,
                decoration: const InputDecoration(labelText: 'Responsável'),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _c['cep'],
                      enabled: !_saving,
                      decoration: const InputDecoration(labelText: 'CEP'),
                      onChanged: (v) {
                        _mask('cep', v, Masks.maskCEP);
                        if (Masks.onlyDigits(_c['cep']!.text).length == 8) {
                          _buscarCep();
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 3,
                    child: TextFormField(
                      controller: _c['cidade'],
                      enabled: !_saving,
                      decoration: const InputDecoration(labelText: 'Cidade'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 80,
                    child: TextFormField(
                      controller: _c['estado'],
                      enabled: !_saving,
                      maxLength: 2,
                      decoration: const InputDecoration(
                          labelText: 'UF', counterText: ''),
                      onChanged: (v) => _c['estado']!.value = TextEditingValue(
                        text: v.toUpperCase(),
                        selection:
                            TextSelection.collapsed(offset: v.length.clamp(0, 2)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _c['endereco'],
                enabled: !_saving,
                decoration: const InputDecoration(labelText: 'Endereço'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _c['observacoes'],
                enabled: !_saving,
                maxLines: 3,
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
                    : Text(_isEdit ? 'Salvar' : 'Cadastrar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
