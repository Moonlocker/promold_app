import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../models/qc.dart';
import '../../../providers/qualidade_providers.dart';
import '../../../providers/supabase_providers.dart';

/// Configuração dos padrões automáticos de código (lote e corpo de prova).
Future<void> showQcPadroesSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => const _QcPadroesSheet(),
  );
}

class _QcPadroesSheet extends ConsumerStatefulWidget {
  const _QcPadroesSheet();

  @override
  ConsumerState<_QcPadroesSheet> createState() => _QcPadroesSheetState();
}

class _QcPadroesSheetState extends ConsumerState<_QcPadroesSheet> {
  final _lotePadrao = TextEditingController(text: 'LOT-{YYYY}{MM}{DD}-{SEQ3}');
  final _loteSigla = TextEditingController();
  final _cpPadrao = TextEditingController(text: 'CP-{SEQ3}');
  final _cpSigla = TextEditingController();
  String _loteReset = 'diario';
  String _cpReset = 'nunca';
  bool _carregado = false;
  bool _saving = false;

  @override
  void dispose() {
    _lotePadrao.dispose();
    _loteSigla.dispose();
    _cpPadrao.dispose();
    _cpSigla.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    setState(() => _saving = true);
    try {
      final repo = ref.read(qualidadeRepositoryProvider);
      final padroes = ref.read(qcPadroesProvider).value ?? const <QcPadrao>[];
      final lote = padroes.where((p) => p.tipo == 'lote').firstOrNull;
      final cp = padroes.where((p) => p.tipo == 'corpo_prova').firstOrNull;
      await repo.savePadrao({
        'tipo': 'lote',
        'padrao': _lotePadrao.text.trim(),
        'sigla': _loteSigla.text.trim(),
        'contador_reset': _loteReset,
        'contador_atual': lote?.contadorAtual ?? 0,
        'ultimo_reset_data': lote?.ultimoResetData,
      }, id: lote?.id);
      await repo.savePadrao({
        'tipo': 'corpo_prova',
        'padrao': _cpPadrao.text.trim(),
        'sigla': _cpSigla.text.trim(),
        'contador_reset': _cpReset,
        'contador_atual': cp?.contadorAtual ?? 0,
        'ultimo_reset_data': cp?.ultimoResetData,
      }, id: cp?.id);
      ref.invalidate(qcPadroesProvider);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erro: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(qcPadroesProvider);
    final padroes = async.value ?? const <QcPadrao>[];
    if (!_carregado && async.hasValue) {
      final lote = padroes.where((p) => p.tipo == 'lote').firstOrNull;
      final cp = padroes.where((p) => p.tipo == 'corpo_prova').firstOrNull;
      if (lote != null) {
        _lotePadrao.text = lote.padrao;
        _loteSigla.text = lote.sigla ?? '';
        _loteReset = lote.contadorReset;
      }
      if (cp != null) {
        _cpPadrao.text = cp.padrao;
        _cpSigla.text = cp.sigla ?? '';
        _cpReset = cp.contadorReset;
      }
      _carregado = true;
    }

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
                const Text('Padrões de código',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Tokens: {YYYY} {YY} {MM} {DD} {HH} {mm} {SIGLA} {SEQ} {SEQ2} {SEQ3} {SEQ4}',
              style: TextStyle(fontSize: 11.5, color: AppColors.mutedForeground),
            ),
            const SizedBox(height: 16),
            const Text('Lote',
                style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            TextField(
              controller: _lotePadrao,
              decoration: const InputDecoration(labelText: 'Padrão'),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _loteSigla,
                    decoration: const InputDecoration(labelText: 'Sigla'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _loteReset,
                    decoration:
                        const InputDecoration(labelText: 'Reset do contador'),
                    items: const [
                      DropdownMenuItem(value: 'nunca', child: Text('Nunca')),
                      DropdownMenuItem(value: 'diario', child: Text('Diário')),
                      DropdownMenuItem(value: 'mensal', child: Text('Mensal')),
                      DropdownMenuItem(value: 'anual', child: Text('Anual')),
                    ],
                    onChanged: (v) =>
                        setState(() => _loteReset = v ?? 'diario'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Text('Corpo de prova',
                style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            TextField(
              controller: _cpPadrao,
              decoration: const InputDecoration(labelText: 'Padrão'),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _cpSigla,
                    decoration: const InputDecoration(labelText: 'Sigla'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _cpReset,
                    decoration:
                        const InputDecoration(labelText: 'Reset do contador'),
                    items: const [
                      DropdownMenuItem(value: 'nunca', child: Text('Nunca')),
                      DropdownMenuItem(value: 'diario', child: Text('Diário')),
                      DropdownMenuItem(value: 'mensal', child: Text('Mensal')),
                      DropdownMenuItem(value: 'anual', child: Text('Anual')),
                    ],
                    onChanged: (v) => setState(() => _cpReset = v ?? 'nunca'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _saving ? null : _salvar,
              child: Text(_saving ? 'Salvando...' : 'Salvar'),
            ),
          ],
        ),
      ),
    );
  }
}
