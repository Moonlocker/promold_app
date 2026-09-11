import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/logic/qc_engine.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../models/qc.dart';
import '../../../providers/qualidade_providers.dart';
import '../../../providers/supabase_providers.dart';

/// Abre o formulário de ensaio para um lote. Retorna `true` se salvou.
Future<bool?> showEnsaioFormSheet(
  BuildContext context, {
  required QcLote lote,
  required List<QcCorpoProva> cps,
  QcEnsaio? ensaio,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _EnsaioFormSheet(lote: lote, cps: cps, ensaio: ensaio),
  );
}

class _EnsaioFormSheet extends ConsumerStatefulWidget {
  const _EnsaioFormSheet({
    required this.lote,
    required this.cps,
    this.ensaio,
  });

  final QcLote lote;
  final List<QcCorpoProva> cps;
  final QcEnsaio? ensaio;

  @override
  ConsumerState<_EnsaioFormSheet> createState() => _EnsaioFormSheetState();
}

class _EnsaioFormSheetState extends ConsumerState<_EnsaioFormSheet> {
  late final TextEditingController _resistencia;
  late final TextEditingController _laboratorio;
  late final TextEditingController _carga;
  late final TextEditingController _observacoes;
  String? _cpId;
  DateTime? _data;
  bool _saving = false;

  bool get _isEdit => widget.ensaio != null;

  @override
  void initState() {
    super.initState();
    final e = widget.ensaio;
    _cpId = e?.corpoProvaId ??
        (widget.cps.isNotEmpty ? widget.cps.first.id : null);
    _resistencia =
        TextEditingController(text: e?.resistenciaMpa.toString() ?? '');
    _laboratorio = TextEditingController(text: e?.laboratorio ?? '');
    _carga = TextEditingController(text: e?.cargaKn?.toString() ?? '');
    _observacoes = TextEditingController(text: e?.observacoes ?? '');
    _data = e != null ? DateTime.tryParse(e.dataEnsaio) : DateTime.now();
  }

  @override
  void dispose() {
    _resistencia.dispose();
    _laboratorio.dispose();
    _carga.dispose();
    _observacoes.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    if (_cpId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione o corpo de prova')),
      );
      return;
    }
    final resistencia = double.tryParse(_resistencia.text.replaceAll(',', '.'));
    if (resistencia == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe a resistência')),
      );
      return;
    }
    final cp = widget.cps.where((c) => c.id == _cpId).firstOrNull;
    final idade = cp?.idadeRompimentoDias;
    final avaliacao = evaluateEnsaio(
      resistencia: resistencia,
      idadeDias: idade,
      idadeHoras: cp?.idadeHoras,
      grupo: cp?.grupo != null ? QcGrupoX.fromValue(cp!.grupo) : null,
      fck: widget.lote.fckMpa,
      fcj: widget.lote.fcjMpa,
    );
    setState(() => _saving = true);
    final payload = <String, dynamic>{
      'corpo_prova_id': _cpId,
      'data_ensaio': Formatters.iso(_data ?? DateTime.now()),
      'resistencia_mpa': resistencia,
      'idade_real_dias': idade,
      'laboratorio':
          _laboratorio.text.trim().isEmpty ? null : _laboratorio.text.trim(),
      'carga_kn': double.tryParse(_carga.text.replaceAll(',', '.')),
      'observacoes':
          _observacoes.text.trim().isEmpty ? null : _observacoes.text.trim(),
      'aprovado': avaliacao.aprovado,
    };
    try {
      final repo = ref.read(qualidadeRepositoryProvider);
      await repo.saveEnsaio(payload, id: widget.ensaio?.id);
      ref.invalidate(qcEnsaiosProvider);
      ref.invalidate(qcEnsaiosLoteProvider(widget.lote.id));
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Text(_isEdit ? 'Editar Ensaio' : 'Novo Ensaio',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w700)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _cpId,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Corpo de prova *'),
              items: widget.cps
                  .map((c) => DropdownMenuItem(
                        value: c.id,
                        child: Text(
                            '${c.identificador} · ${c.idadeRompimentoDias}d'),
                      ))
                  .toList(),
              onChanged: _saving ? null : (v) => setState(() => _cpId = v),
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: _saving
                  ? null
                  : () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _data ?? DateTime.now(),
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) setState(() => _data = picked);
                    },
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Data do ensaio',
                  suffixIcon: Icon(Icons.calendar_today_outlined, size: 18),
                ),
                child: Text(Formatters.dataBr(_data)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _resistencia,
              enabled: !_saving,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration:
                  const InputDecoration(labelText: 'Resistência (MPa) *'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _carga,
                    enabled: !_saving,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Carga (kN)'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _laboratorio,
                    enabled: !_saving,
                    decoration: const InputDecoration(labelText: 'Laboratório'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
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
                  : const Text('Salvar'),
            ),
          ],
        ),
      ),
    );
  }
}
