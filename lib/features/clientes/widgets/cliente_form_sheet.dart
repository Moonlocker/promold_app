import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/cep.dart';
import '../../../core/utils/masks.dart';
import '../../../models/cliente.dart';
import '../../../providers/cadastros_providers.dart';
import '../../../providers/supabase_providers.dart';

/// Abre o formulário de cliente. Retorna `true` se salvou.
Future<bool?> showClienteFormSheet(BuildContext context, {Cliente? cliente}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _ClienteFormSheet(cliente: cliente),
  );
}

class _ClienteFormSheet extends ConsumerStatefulWidget {
  const _ClienteFormSheet({this.cliente});

  final Cliente? cliente;

  @override
  ConsumerState<_ClienteFormSheet> createState() => _ClienteFormSheetState();
}

class _ClienteFormSheetState extends ConsumerState<_ClienteFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final Map<String, TextEditingController> _c;
  String _tipoPessoa = 'PJ';
  bool _ativo = true;
  bool _saving = false;

  bool get _isEdit => widget.cliente != null;

  @override
  void initState() {
    super.initState();
    final c = widget.cliente;
    _tipoPessoa = c?.tipoPessoa ?? 'PJ';
    _ativo = c?.ativo ?? true;
    _c = {
      'nome': TextEditingController(text: c?.nome ?? ''),
      'cpf_cnpj': TextEditingController(text: c?.cpfCnpj ?? ''),
      'inscricao_estadual': TextEditingController(text: c?.inscricaoEstadual ?? ''),
      'inscricao_municipal': TextEditingController(text: c?.inscricaoMunicipal ?? ''),
      'email': TextEditingController(text: c?.email ?? ''),
      'telefone': TextEditingController(text: c?.telefone ?? ''),
      'whatsapp': TextEditingController(text: c?.whatsapp ?? ''),
      'contato_principal': TextEditingController(text: c?.contatoPrincipal ?? ''),
      'cep': TextEditingController(text: c?.cep ?? ''),
      'logradouro': TextEditingController(text: c?.logradouro ?? ''),
      'numero': TextEditingController(text: c?.numero ?? ''),
      'complemento': TextEditingController(text: c?.complemento ?? ''),
      'bairro': TextEditingController(text: c?.bairro ?? ''),
      'cidade': TextEditingController(text: c?.cidade ?? ''),
      'uf': TextEditingController(text: c?.uf ?? ''),
      'observacoes': TextEditingController(text: c?.observacoes ?? ''),
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
      if (info.logradouro != null) _c['logradouro']!.text = info.logradouro!;
      if (info.bairro != null) _c['bairro']!.text = info.bairro!;
      if (info.cidade != null) _c['cidade']!.text = info.cidade!;
      if (info.uf != null) _c['uf']!.text = info.uf!;
    });
  }

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final payload = <String, dynamic>{
      'nome': _c['nome']!.text.trim(),
      'tipo_pessoa': _tipoPessoa,
      'cpf_cnpj': _nz('cpf_cnpj'),
      'inscricao_estadual': _nz('inscricao_estadual'),
      'inscricao_municipal': _nz('inscricao_municipal'),
      'email': _nz('email'),
      'telefone': _nz('telefone'),
      'whatsapp': _nz('whatsapp'),
      'contato_principal': _nz('contato_principal'),
      'cep': _nz('cep'),
      'logradouro': _nz('logradouro'),
      'numero': _nz('numero'),
      'complemento': _nz('complemento'),
      'bairro': _nz('bairro'),
      'cidade': _nz('cidade'),
      'uf': _nz('uf'),
      'observacoes': _nz('observacoes'),
      'ativo': _ativo,
    };
    try {
      final repo = ref.read(clientesRepositoryProvider);
      if (_isEdit) {
        await repo.update(widget.cliente!.id, payload);
      } else {
        await repo.create(payload);
      }
      ref.invalidate(clientesListProvider);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erro: $e')));
      }
    }
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
                    _isEdit ? 'Editar Cliente' : 'Novo Cliente',
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
                controller: _c['nome'],
                enabled: !_saving,
                decoration:
                    const InputDecoration(labelText: 'Nome / Razão Social *'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Informe o nome' : null,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _tipoPessoa,
                      decoration: const InputDecoration(labelText: 'Tipo'),
                      items: const [
                        DropdownMenuItem(value: 'PJ', child: Text('Pessoa Jurídica')),
                        DropdownMenuItem(value: 'PF', child: Text('Pessoa Física')),
                      ],
                      onChanged: _saving
                          ? null
                          : (v) => setState(() => _tipoPessoa = v ?? 'PJ'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _c['cpf_cnpj'],
                      enabled: !_saving,
                      decoration: InputDecoration(
                        labelText: _tipoPessoa == 'PF' ? 'CPF' : 'CNPJ',
                      ),
                      onChanged: (v) {
                        final d = Masks.onlyDigits(v);
                        _c['cpf_cnpj']!.value = TextEditingValue(
                          text: _tipoPessoa == 'PF'
                              ? Masks.maskCPF(d)
                              : Masks.maskCNPJ(d),
                          selection: TextSelection.collapsed(
                            offset: _tipoPessoa == 'PF'
                                ? Masks.maskCPF(d).length
                                : Masks.maskCNPJ(d).length,
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _c['inscricao_estadual'],
                      enabled: !_saving,
                      decoration: const InputDecoration(
                          labelText: 'Inscrição Estadual'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _c['inscricao_municipal'],
                      enabled: !_saving,
                      decoration: const InputDecoration(
                          labelText: 'Inscrição Municipal'),
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
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _c['telefone'],
                      enabled: !_saving,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(labelText: 'Telefone'),
                      onChanged: (v) => _maskPhone('telefone', v),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _c['whatsapp'],
                      enabled: !_saving,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(labelText: 'WhatsApp'),
                      onChanged: (v) => _maskPhone('whatsapp', v),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _c['contato_principal'],
                enabled: !_saving,
                decoration:
                    const InputDecoration(labelText: 'Contato principal'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _c['cep'],
                enabled: !_saving,
                decoration: const InputDecoration(labelText: 'CEP'),
                onChanged: (v) {
                  final m = Masks.maskCEP(v);
                  _c['cep']!.value = TextEditingValue(
                    text: m,
                    selection: TextSelection.collapsed(offset: m.length),
                  );
                  if (Masks.onlyDigits(m).length == 8) _buscarCep();
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _c['logradouro'],
                enabled: !_saving,
                decoration: const InputDecoration(labelText: 'Logradouro'),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _c['numero'],
                      enabled: !_saving,
                      decoration: const InputDecoration(labelText: 'Número'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _c['complemento'],
                      enabled: !_saving,
                      decoration:
                          const InputDecoration(labelText: 'Complemento'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _c['bairro'],
                      enabled: !_saving,
                      decoration: const InputDecoration(labelText: 'Bairro'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
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
                      controller: _c['uf'],
                      enabled: !_saving,
                      maxLength: 2,
                      decoration: const InputDecoration(
                          labelText: 'UF', counterText: ''),
                      onChanged: (v) => _c['uf']!.value = TextEditingValue(
                        text: v.toUpperCase(),
                        selection: TextSelection.collapsed(
                            offset: v.length.clamp(0, 2)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _c['observacoes'],
                enabled: !_saving,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Observações'),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Cliente ativo'),
                value: _ativo,
                onChanged:
                    _saving ? null : (v) => setState(() => _ativo = v),
              ),
              const SizedBox(height: 12),
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

  void _maskPhone(String key, String value) {
    final m = Masks.maskPhone(value);
    _c[key]!.value = TextEditingValue(
      text: m,
      selection: TextSelection.collapsed(offset: m.length),
    );
  }
}
