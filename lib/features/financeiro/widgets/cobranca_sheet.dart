import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../models/conta_financeira.dart';
import '../../../providers/financeiro_providers.dart';
import '../../../providers/supabase_providers.dart';

/// Gera/reaproveita cobrança PIX ou Boleto no Asaas para uma conta a receber.
Future<void> showCobrancaSheet(
  BuildContext context, {
  required ContaFinanceira conta,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _CobrancaSheet(conta: conta),
  );
}

class _CobrancaSheet extends ConsumerStatefulWidget {
  const _CobrancaSheet({required this.conta});

  final ContaFinanceira conta;

  @override
  ConsumerState<_CobrancaSheet> createState() => _CobrancaSheetState();
}

class _CobrancaSheetState extends ConsumerState<_CobrancaSheet> {
  String _tab = 'PIX';
  bool _loading = false;
  Map<String, dynamic>? _result;

  String? get _pixQr => (_result?['pixQrCode'] as String?) ??
      widget.conta.asaasPixQrCode;
  String? get _pixCopia =>
      (_result?['pixCopiaCola'] as String?) ?? widget.conta.asaasPixCopiaCola;
  String? get _boletoUrl =>
      (_result?['boletoUrl'] as String?) ?? widget.conta.asaasBoletoUrl;
  String? get _linha =>
      (_result?['linhaDigitavel'] as String?) ??
      widget.conta.asaasLinhaDigitavel;
  String? get _invoice =>
      (_result?['invoiceUrl'] as String?) ?? widget.conta.asaasInvoiceUrl;

  Future<void> _gerar({bool force = false}) async {
    setState(() => _loading = true);
    try {
      final data = await ref
          .read(financeiroRepositoryProvider)
          .gerarCobrancaAsaas(
            contaId: widget.conta.id,
            billingType: _tab,
            forceRegenerate: force,
          );
      setState(() => _result = data);
      ref.invalidate(contasReceberListProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(force ? 'Cobrança regerada' : 'Cobrança gerada')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'.replaceFirst('Exception: ', ''))),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.conta;
    final restante = c.restante;

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
                const Icon(Icons.bolt, color: AppColors.primary),
                const SizedBox(width: 8),
                const Text('Cobrança Asaas',
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
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.muted,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(c.descricao,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  Text('Cliente: ${c.cliente ?? '—'}',
                      style: const TextStyle(fontSize: 12.5)),
                  Text('Restante: ${Formatters.moeda(restante)}',
                      style: const TextStyle(fontSize: 12.5)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'PIX', label: Text('PIX')),
                ButtonSegment(value: 'BOLETO', label: Text('Boleto')),
              ],
              selected: {_tab},
              onSelectionChanged: (s) => setState(() => _tab = s.first),
            ),
            const SizedBox(height: 16),
            if (_tab == 'PIX' && _pixQr != null) ...[
              Center(
                child: Container(
                  padding: const EdgeInsets.all(8),
                  color: Colors.white,
                  child: Image.memory(
                    base64Decode(_pixQr!),
                    width: 200,
                    height: 200,
                    errorBuilder: (_, _, _) => const SizedBox(
                      width: 200,
                      height: 200,
                      child: Center(child: Text('QR indisponível')),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (_pixCopia != null)
                OutlinedButton.icon(
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: _pixCopia!));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('PIX copiado')),
                      );
                    }
                  },
                  icon: const Icon(Icons.copy, size: 18),
                  label: const Text('Copiar PIX copia e cola'),
                ),
            ] else if (_tab == 'BOLETO' && _boletoUrl != null) ...[
              FilledButton.tonalIcon(
                onPressed: () => launchUrl(Uri.parse(_boletoUrl!)),
                icon: const Icon(Icons.open_in_new, size: 18),
                label: const Text('Abrir boleto'),
              ),
              const SizedBox(height: 12),
              if (_linha != null)
                OutlinedButton.icon(
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: _linha!));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Linha digitável copiada')),
                      );
                    }
                  },
                  icon: const Icon(Icons.copy, size: 18),
                  label: const Text('Copiar linha digitável'),
                ),
            ] else
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'Clique em gerar para criar a cobrança.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.mutedForeground),
                ),
              ),
            if (_invoice != null) ...[
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () => launchUrl(Uri.parse(_invoice!)),
                icon: const Icon(Icons.open_in_new, size: 16),
                label: const Text('Página de pagamento Asaas'),
              ),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _loading ? null : () => _gerar(force: _result != null),
              child: _loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.4, color: Colors.white),
                    )
                  : Text(_result != null
                      ? 'Regerar ${_tab == 'PIX' ? 'PIX' : 'boleto'}'
                      : 'Gerar ${_tab == 'PIX' ? 'PIX' : 'boleto'}'),
            ),
          ],
        ),
      ),
    );
  }
}
