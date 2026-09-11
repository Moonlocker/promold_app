import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../models/funcionario.dart';
import '../../../providers/equipe_providers.dart';
import '../../../providers/supabase_providers.dart';

/// Abre o formulário de funcionário. Retorna `true` se salvou.
Future<bool?> showFuncionarioFormSheet(
  BuildContext context, {
  Funcionario? funcionario,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _FuncionarioFormSheet(funcionario: funcionario),
  );
}

class _FuncionarioFormSheet extends ConsumerStatefulWidget {
  const _FuncionarioFormSheet({this.funcionario});

  final Funcionario? funcionario;

  @override
  ConsumerState<_FuncionarioFormSheet> createState() =>
      _FuncionarioFormSheetState();
}

class _FuncionarioFormSheetState
    extends ConsumerState<_FuncionarioFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nome;
  late final TextEditingController _salario;
  late final TextEditingController _telefone;
  late final TextEditingController _email;

  String? _cargoId;
  String? _setorId;
  String? _fotoUrl;
  DateTime? _dataAdmissao;
  bool _ativo = true;
  bool _saving = false;

  bool get _isEdit => widget.funcionario != null;

  @override
  void initState() {
    super.initState();
    final f = widget.funcionario;
    _nome = TextEditingController(text: f?.nome ?? '');
    _salario = TextEditingController(text: f?.salario?.toString() ?? '');
    _telefone = TextEditingController(text: f?.telefone ?? '');
    _email = TextEditingController(text: f?.email ?? '');
    _cargoId = f?.cargoId;
    _setorId = f?.setorId;
    _fotoUrl = f?.fotoUrl;
    _ativo = f?.ativo ?? true;
    _dataAdmissao =
        f?.dataAdmissao != null ? DateTime.tryParse(f!.dataAdmissao!) : null;
  }

  @override
  void dispose() {
    _nome.dispose();
    _salario.dispose();
    _telefone.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _escolherFoto() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (file == null) return;
    try {
      final bytes = await file.readAsBytes();
      final ext = file.name.split('.').last;
      final url = await ref
          .read(equipeRepositoryProvider)
          .uploadFotoFuncionario(bytes: bytes, extensao: ext);
      if (mounted) setState(() => _fotoUrl = url);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erro ao enviar foto: $e')));
      }
    }
  }

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;
    if (_cargoId == null || _setorId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione cargo e setor')),
      );
      return;
    }
    setState(() => _saving = true);
    final payload = <String, dynamic>{
      'nome': _nome.text.trim(),
      'cargo_id': _cargoId,
      'setor_id': _setorId,
      'salario': double.tryParse(_salario.text.replaceAll(',', '.')),
      'telefone': _telefone.text.trim().isEmpty ? null : _telefone.text.trim(),
      'email': _email.text.trim().isEmpty ? null : _email.text.trim(),
      'ativo': _ativo,
      'foto_url': _fotoUrl,
      'data_admissao':
          _dataAdmissao != null ? Formatters.iso(_dataAdmissao!) : null,
    };
    try {
      final repo = ref.read(equipeRepositoryProvider);
      if (_isEdit) {
        await repo.updateFuncionario(widget.funcionario!.id, payload);
      } else {
        await repo.createFuncionario(payload);
      }
      ref.invalidate(funcionariosListProvider);
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
    final setores = ref.watch(setoresListProvider).value ?? const [];
    final cargos = ref.watch(cargosListProvider).value ?? const [];

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
                    _isEdit ? 'Editar Funcionário' : 'Novo Funcionário',
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
              Center(
                child: GestureDetector(
                  onTap: _saving ? null : _escolherFoto,
                  child: CircleAvatar(
                    radius: 36,
                    backgroundColor: AppColors.muted,
                    backgroundImage:
                        _fotoUrl != null ? NetworkImage(_fotoUrl!) : null,
                    child: _fotoUrl == null
                        ? const Icon(Icons.camera_alt_outlined,
                            color: AppColors.mutedForeground)
                        : null,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nome,
                enabled: !_saving,
                decoration: const InputDecoration(labelText: 'Nome completo *'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Informe o nome' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _cargoId,
                decoration: const InputDecoration(labelText: 'Cargo *'),
                items: cargos
                    .where((c) => c.ativo)
                    .map((c) => DropdownMenuItem(
                          value: c.id,
                          child: Text(c.nome),
                        ))
                    .toList(),
                onChanged: _saving
                    ? null
                    : (v) {
                        final cargo = cargos.where((c) => c.id == v).firstOrNull;
                        setState(() {
                          _cargoId = v;
                          if (cargo?.setorId != null) _setorId = cargo!.setorId;
                          if (cargo?.salario != null) {
                            _salario.text = cargo!.salario.toString();
                          }
                        });
                      },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _setorId,
                decoration: const InputDecoration(labelText: 'Setor *'),
                items: setores
                    .where((s) => s.ativo)
                    .map((s) => DropdownMenuItem(
                          value: s.id,
                          child: Text(s.nome),
                        ))
                    .toList(),
                onChanged: _saving
                    ? null
                    : (v) => setState(() => _setorId = v),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _salario,
                      enabled: !_saving,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      decoration: const InputDecoration(
                          labelText: 'Salário (R\$)'),
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
                                initialDate: _dataAdmissao ?? DateTime.now(),
                                firstDate: DateTime(1990),
                                lastDate: DateTime(2100),
                              );
                              if (picked != null) {
                                setState(() => _dataAdmissao = picked);
                              }
                            },
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Admissão',
                          suffixIcon: Icon(Icons.calendar_today_outlined,
                              size: 18),
                        ),
                        child: Text(
                          _dataAdmissao != null
                              ? Formatters.dataBr(_dataAdmissao)
                              : 'Selecionar',
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _telefone,
                      enabled: !_saving,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(labelText: 'Telefone'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _email,
                      enabled: !_saving,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(labelText: 'E-mail'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Funcionário ativo'),
                value: _ativo,
                onChanged: _saving ? null : (v) => setState(() => _ativo = v),
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
}
