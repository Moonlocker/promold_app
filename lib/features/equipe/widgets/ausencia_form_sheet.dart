import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../models/ausencia.dart';
import '../../../providers/equipe_providers.dart';
import '../../../providers/supabase_providers.dart';

/// Abre o formulário de ausência. Retorna `true` se salvou.
Future<bool?> showAusenciaFormSheet(
  BuildContext context, {
  Ausencia? ausencia,
  String? funcionarioIdFixo,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _AusenciaFormSheet(
      ausencia: ausencia,
      funcionarioIdFixo: funcionarioIdFixo,
    ),
  );
}

class _AusenciaFormSheet extends ConsumerStatefulWidget {
  const _AusenciaFormSheet({this.ausencia, this.funcionarioIdFixo});

  final Ausencia? ausencia;
  final String? funcionarioIdFixo;

  @override
  ConsumerState<_AusenciaFormSheet> createState() => _AusenciaFormSheetState();
}

class _AusenciaFormSheetState extends ConsumerState<_AusenciaFormSheet> {
  String? _funcionarioId;
  String _tipo = 'falta';
  DateTime? _inicio;
  DateTime? _fim;
  final _motivo = TextEditingController();
  bool _saving = false;

  bool get _isEdit => widget.ausencia != null;

  @override
  void initState() {
    super.initState();
    final a = widget.ausencia;
    _funcionarioId = a?.funcionarioId ?? widget.funcionarioIdFixo;
    _tipo = a?.tipo ?? 'falta';
    _inicio = a != null ? DateTime.tryParse(a.dataInicio) : DateTime.now();
    _fim = a != null ? DateTime.tryParse(a.dataFim) : DateTime.now();
    _motivo.text = a?.motivo ?? '';
  }

  @override
  void dispose() {
    _motivo.dispose();
    super.dispose();
  }

  Future<void> _pickDate(bool inicio) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: (inicio ? _inicio : _fim) ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => inicio ? _inicio = picked : _fim = picked);
    }
  }

  Future<void> _salvar() async {
    if (_funcionarioId == null || _inicio == null || _fim == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe funcionário e datas')),
      );
      return;
    }
    if (_fim!.isBefore(_inicio!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Data fim anterior à data início')),
      );
      return;
    }
    setState(() => _saving = true);
    final payload = <String, dynamic>{
      'funcionario_id': _funcionarioId,
      'tipo': _tipo,
      'data_inicio': Formatters.iso(_inicio!),
      'data_fim': Formatters.iso(_fim!),
      'motivo': _motivo.text.trim().isEmpty ? null : _motivo.text.trim(),
    };
    try {
      final repo = ref.read(equipeRepositoryProvider);
      if (_isEdit) {
        await repo.updateAusencia(widget.ausencia!.id, payload);
      } else {
        await repo.createAusencia(payload);
      }
      ref.invalidate(ausenciasListProvider);
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
    final funcionarios = ref.watch(funcionariosListProvider).value ?? const [];
    final fixo = widget.funcionarioIdFixo != null;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        20 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Text(
                  _isEdit ? 'Editar Ausência' : 'Registrar Ausência',
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
            if (!fixo)
              DropdownButtonFormField<String>(
                initialValue: _funcionarioId,
                decoration:
                    const InputDecoration(labelText: 'Funcionário *'),
                items: funcionarios
                    .where((f) => f.ativo)
                    .map((f) => DropdownMenuItem(
                          value: f.id,
                          child: Text(f.nome),
                        ))
                    .toList(),
                onChanged:
                    _saving ? null : (v) => setState(() => _funcionarioId = v),
              )
            else
              Text(
                funcionarios
                        .where((f) => f.id == _funcionarioId)
                        .firstOrNull
                        ?.nome ??
                    'Funcionário',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _tipo,
              decoration: const InputDecoration(labelText: 'Tipo'),
              items: const [
                DropdownMenuItem(value: 'falta', child: Text('Falta')),
                DropdownMenuItem(value: 'atestado', child: Text('Atestado')),
                DropdownMenuItem(value: 'ferias', child: Text('Férias')),
                DropdownMenuItem(value: 'licenca', child: Text('Licença')),
                DropdownMenuItem(value: 'outro', child: Text('Outro')),
              ],
              onChanged:
                  _saving ? null : (v) => setState(() => _tipo = v ?? 'falta'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _DateField(
                    label: 'Início',
                    value: _inicio,
                    onTap: _saving ? null : () => _pickDate(true),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _DateField(
                    label: 'Fim',
                    value: _fim,
                    onTap: _saving ? null : () => _pickDate(false),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _motivo,
              enabled: !_saving,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Motivo'),
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
                  : Text(_isEdit ? 'Salvar' : 'Registrar'),
            ),
          ],
        ),
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({required this.label, required this.value, this.onTap});

  final String label;
  final DateTime? value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: const Icon(Icons.calendar_today_outlined, size: 18),
        ),
        child: Text(value != null ? Formatters.dataBr(value) : 'Selecionar'),
      ),
    );
  }
}
