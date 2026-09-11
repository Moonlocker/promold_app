import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../models/sistema.dart';
import '../../../providers/sistema_providers.dart';
import '../../../providers/supabase_providers.dart';

const _meses = [
  'Jan', 'Fev', 'Mar', 'Abr', 'Mai', 'Jun',
  'Jul', 'Ago', 'Set', 'Out', 'Nov', 'Dez',
];

/// Módulo Minha Fatura: faturas da assinatura da organização.
class MinhaFaturaScreen extends ConsumerStatefulWidget {
  const MinhaFaturaScreen({super.key});

  @override
  ConsumerState<MinhaFaturaScreen> createState() => _MinhaFaturaScreenState();
}

class _MinhaFaturaScreenState extends ConsumerState<MinhaFaturaScreen> {
  @override
  Widget build(BuildContext context) {
    final async = ref.watch(faturasSaasProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Minha Fatura')),
      body: async.when(
        loading: () => const LoadingView(),
        error: (e, _) => Center(child: Text('Erro: $e')),
        data: (faturas) {
          if (faturas.isEmpty) {
            return const EmptyState(
              icon: Icons.receipt_outlined,
              title: 'Nenhuma fatura',
              message: 'As faturas da assinatura aparecerão aqui.',
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(faturasSaasProvider),
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              itemCount: faturas.length,
              itemBuilder: (context, i) => _FaturaCard(
                fatura: faturas[i],
                onChanged: () => ref.invalidate(faturasSaasProvider),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _FaturaCard extends ConsumerWidget {
  const _FaturaCard({required this.fatura, required this.onChanged});

  final FaturaSaas fatura;
  final VoidCallback onChanged;

  Color get _cor => switch (fatura.status) {
        'paga' => AppColors.success,
        'vencida' => AppColors.destructive,
        _ => AppColors.warning,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${_meses[(fatura.mes - 1).clamp(0, 11)]}/${fatura.ano}'
                    '${fatura.planoNome != null ? ' · ${fatura.planoNome}' : ''}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _cor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    fatura.status,
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _cor),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Total: ${Formatters.moeda(fatura.valorTotal)}'
              '${fatura.dataVencimento != null ? ' · Venc. ${Formatters.dataBr(DateTime.tryParse(fatura.dataVencimento!))}' : ''}',
              style: const TextStyle(fontSize: 12.5),
            ),
            if (!fatura.paga) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _gerar(context, ref, 'PIX'),
                      icon: const Icon(Icons.qr_code, size: 18),
                      label: const Text('PIX'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _gerar(context, ref, 'BOLETO'),
                      icon: const Icon(Icons.receipt, size: 18),
                      label: const Text('Boleto'),
                    ),
                  ),
                ],
              ),
            ],
            if (fatura.paymentUrl != null) ...[
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () => launchUrl(Uri.parse(fatura.paymentUrl!)),
                icon: const Icon(Icons.open_in_new, size: 16),
                label: const Text('Abrir página de pagamento'),
              ),
            ],
            if (fatura.notaFiscalUrl != null) ...[
              TextButton.icon(
                onPressed: () => launchUrl(Uri.parse(fatura.notaFiscalUrl!)),
                icon: const Icon(Icons.description_outlined, size: 16),
                label: const Text('Nota fiscal'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _gerar(BuildContext context, WidgetRef ref, String metodo) async {
    try {
      final data = await ref
          .read(sistemaRepositoryProvider)
          .gerarCobrancaFatura(faturaId: fatura.id, metodo: metodo);
      onChanged();
      if (!context.mounted) return;
      if (metodo == 'PIX' && data['qrCode'] != null) {
        await _mostrarPix(context, data);
      } else if (data['bankSlipUrl'] != null) {
        await launchUrl(Uri.parse(data['bankSlipUrl']));
      } else if (data['invoiceUrl'] != null) {
        await launchUrl(Uri.parse(data['invoiceUrl']));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'.replaceFirst('Exception: ', ''))),
        );
      }
    }
  }

  Future<void> _mostrarPix(
    BuildContext context,
    Map<String, dynamic> data,
  ) async {
    final qr = data['qrCode'] as String?;
    final copia = data['copiaECola'] as String?;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('PIX'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (qr != null)
              Image.memory(base64Decode(qr),
                  width: 200,
                  height: 200,
                  errorBuilder: (_, _, _) =>
                      const Icon(Icons.qr_code, size: 120)),
            if (copia != null) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: copia));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('PIX copiado')),
                    );
                  }
                },
                icon: const Icon(Icons.copy, size: 16),
                label: const Text('Copiar código'),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
  }
}
