import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/logic/qc_engine.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../models/qc.dart';
import '../../../providers/auth_providers.dart';
import '../../../providers/qualidade_providers.dart';
import '../../../providers/supabase_providers.dart';

/// Abre o formulário de lote. Retorna `true` se salvou.
Future<bool?> showLoteFormSheet(BuildContext context, {QcLote? lote}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _LoteFormSheet(lote: lote),
  );
}

class _LoteFormSheet extends ConsumerStatefulWidget {
  const _LoteFormSheet({this.lote});

  final QcLote? lote;

  @override
  ConsumerState<_LoteFormSheet> createState() => _LoteFormSheetState();
}

class _LoteFormSheetState extends ConsumerState<_LoteFormSheet> {
  late final TextEditingController _codigo;
  late final TextEditingController _fck;
  late final TextEditingController _fcj;
  late final TextEditingController _volume;
  late final TextEditingController _fornecedor;
  late final TextEditingController _responsavel;
  late final TextEditingController _laboratorista;
  late final TextEditingController _traco;
  late final TextEditingController _slump;
  late final TextEditingController _observacoes;

  DateTime? _data;
  String? _obraId;
  String _template = 'completo-6';
  bool _saving = false;

  bool get _isEdit => widget.lote != null;

  @override
  void initState() {
    super.initState();
    final l = widget.lote;
    _codigo = TextEditingController(text: l?.codigo ?? '');
    _fck = TextEditingController(text: l?.fckMpa.toString() ?? '');
    _fcj = TextEditingController(text: l?.fcjMpa?.toString() ?? '');
    _volume = TextEditingController(text: l?.volumeM3?.toString() ?? '');
    _fornecedor = TextEditingController(text: l?.fornecedor ?? '');
    _responsavel = TextEditingController(text: l?.responsavel ?? '');
    _laboratorista = TextEditingController(text: l?.laboratorista ?? '');
    _traco = TextEditingController(text: l?.traco ?? '');
    _slump = TextEditingController(text: l?.slump ?? '');
    _observacoes = TextEditingController(text: l?.observacoes ?? '');
    _data = l != null ? DateTime.tryParse(l.dataConcretagem) : DateTime.now();
    _obraId = l?.obraId;
  }

  @override
  void dispose() {
    for (final c in [
      _codigo,
      _fck,
      _fcj,
      _volume,
      _fornecedor,
      _responsavel,
      _laboratorista,
      _traco,
      _slump,
      _observacoes,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _gerarCodigo() {
    final padroes = ref.read(qcPadroesProvider).value ?? const <QcPadrao>[];
    final padrao = padroes.where((p) => p.tipo == 'lote').firstOrNull;
    if (padrao == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Configure um padrão de código para lotes')),
      );
      return;
    }
    final reset = shouldReset(
        resetModeFromValue(padrao.contadorReset), padrao.ultimoResetData);
    final seq = (reset ? 0 : padrao.contadorAtual) + 1;
    setState(() {
      _codigo.text = renderQcCodigo(padrao.padrao, sigla: padrao.sigla, seq: seq);
    });
  }

  Future<void> _salvar() async {
    if (_codigo.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe o código do lote')),
      );
      return;
    }
    if (_data == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe a data de concretagem')),
      );
      return;
    }
    final fck = double.tryParse(_fck.text.replaceAll(',', '.'));
    if (fck == null || fck <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe o FCK')),
      );
      return;
    }
    setState(() => _saving = true);
    final payload = <String, dynamic>{
      'codigo': _codigo.text.trim(),
      'data_concretagem': Formatters.iso(_data!),
      'fck_mpa': fck,
      'fcj_mpa': double.tryParse(_fcj.text.replaceAll(',', '.')),
      'volume_m3': double.tryParse(_volume.text.replaceAll(',', '.')),
      'fornecedor': _fornecedor.text.trim().isEmpty ? null : _fornecedor.text.trim(),
      'responsavel': _responsavel.text.trim().isEmpty ? null : _responsavel.text.trim(),
      'laboratorista':
          _laboratorista.text.trim().isEmpty ? null : _laboratorista.text.trim(),
      'traco': _traco.text.trim().isEmpty ? null : _traco.text.trim(),
      'slump': _slump.text.trim().isEmpty ? null : _slump.text.trim(),
      'observacoes':
          _observacoes.text.trim().isEmpty ? null : _observacoes.text.trim(),
      'obra_id': _obraId,
    };
    try {
      final repo = ref.read(qualidadeRepositoryProvider);
      if (_isEdit) {
        await repo.saveLote(payload, id: widget.lote!.id);
      } else {
        final id = await repo.saveLote(payload);
        // Cria os corpos de prova a partir do template escolhido.
        final padroes = ref.read(qcPadroesProvider).value ?? const <QcPadrao>[];
        final padraoCp =
            padroes.where((p) => p.tipo == 'corpo_prova').firstOrNull;
        await repo.createCpsFromTemplate(
          loteId: id,
          dataMoldagem: Formatters.iso(_data!),
          templateSlug: _template,
          padraoCp: padraoCp,
        );
      }
      ref.invalidate(qcLotesProvider);
      ref.invalidate(qcCpsProvider);
      ref.invalidate(qcPadroesProvider);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final obras = ref.watch(obrasListProvider).value ?? const [];
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
                Text(_isEdit ? 'Editar Lote' : 'Novo Lote',
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
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _codigo,
                    enabled: !_saving,
                    decoration: const InputDecoration(labelText: 'Código *'),
                  ),
                ),
                IconButton(
                  onPressed: _saving ? null : _gerarCodigo,
                  icon: const Icon(Icons.autorenew),
                  tooltip: 'Gerar código',
                ),
              ],
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
                  labelText: 'Data de concretagem *',
                  suffixIcon: Icon(Icons.calendar_today_outlined, size: 18),
                ),
                child: Text(Formatters.dataBr(_data)),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _fck,
                    enabled: !_saving,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'FCK (MPa) *'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _fcj,
                    enabled: !_saving,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration:
                        const InputDecoration(labelText: 'FCJ (MPa)'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _volume,
                    enabled: !_saving,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration:
                        const InputDecoration(labelText: 'Volume (m³)'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _slump,
                    enabled: !_saving,
                    decoration: const InputDecoration(labelText: 'Slump'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _traco,
              enabled: !_saving,
              decoration: const InputDecoration(labelText: 'Traço'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _fornecedor,
              enabled: !_saving,
              decoration: const InputDecoration(labelText: 'Fornecedor'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _responsavel,
                    enabled: !_saving,
                    decoration: const InputDecoration(labelText: 'Responsável'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _laboratorista,
                    enabled: !_saving,
                    decoration:
                        const InputDecoration(labelText: 'Laboratorista'),
                  ),
                ),
              ],
            ),
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
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _template,
                decoration: const InputDecoration(
                    labelText: 'Template de corpos de prova'),
                items: qcTemplates
                    .map((t) => DropdownMenuItem(
                          value: t.slug,
                          child: Text(t.nome),
                        ))
                    .toList(),
                onChanged:
                    _saving ? null : (v) => setState(() => _template = v ?? ''),
              ),
              const SizedBox(height: 4),
              Text(
                getTemplateBySlug(_template)?.descricao ?? '',
                style: const TextStyle(
                    fontSize: 11.5, color: AppColors.mutedForeground),
              ),
            ],
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
                  : Text(_isEdit ? 'Salvar' : 'Cadastrar'),
            ),
          ],
        ),
      ),
    );
  }
}
