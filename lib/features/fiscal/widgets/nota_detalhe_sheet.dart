import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../models/nota_fiscal.dart';
import '../../../providers/fiscal_providers.dart';

/// Detalhe de uma nota fiscal (dados + itens).
Future<void> showNotaDetalheSheet(
  BuildContext context, {
  required NotaFiscal nota,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _NotaDetalheSheet(nota: nota),
  );
}

class _NotaDetalheSheet extends ConsumerWidget {
  const _NotaDetalheSheet({required this.nota});

  final NotaFiscal nota;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itensAsync = ref.watch(notasFiscaisItensProvider(nota.id));
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.85,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    nota.numero != null
                        ? 'Nota ${nota.numero}/${nota.serie}'
                        : 'Nota (rascunho)',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _linha('Status', nota.status),
            _linha('Ambiente', nota.ambiente),
            _linha('Tipo', nota.tipoDocumento.toUpperCase()),
            _linha('Natureza', nota.naturezaOperacao ?? '—'),
            _linha(
                'Emissão',
                nota.dataEmissao != null
                    ? Formatters.dataHoraBr(
                        DateTime.tryParse(nota.dataEmissao!))
                    : '—'),
            _linha('Cliente', nota.clienteNome ?? '—'),
            if (nota.chaveAcesso != null) _linha('Chave', nota.chaveAcesso!),
            if (nota.protocolo != null) _linha('Protocolo', nota.protocolo!),
            if (nota.mensagemSefaz != null)
              _linha('SEFAZ', nota.mensagemSefaz!),
            const Divider(height: 24),
            const Text('Itens', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Expanded(
              child: itensAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Text('Erro: $e'),
                data: (itens) {
                  if (itens.isEmpty) {
                    return const Text('Sem itens',
                        style: TextStyle(color: AppColors.mutedForeground));
                  }
                  return ListView(
                    children: itens
                        .map((it) => ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              title: Text(it.descricao),
                              subtitle: Text(
                                'NCM ${it.ncm ?? '—'} · CFOP ${it.cfop ?? '—'} · '
                                '${it.quantidade ?? 0} ${it.unidade ?? ''}',
                                style: const TextStyle(fontSize: 11.5),
                              ),
                              trailing: Text(
                                Formatters.moeda(it.valorTotal ?? 0),
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600),
                              ),
                            ))
                        .toList(),
                  );
                },
              ),
            ),
            const Divider(height: 24),
            Row(
              children: [
                Expanded(
                  child: _total('Produtos', nota.valorProdutos ?? 0),
                ),
                Expanded(child: _total('Frete', nota.valorFrete ?? 0)),
                Expanded(child: _total('Desconto', nota.valorDesconto ?? 0)),
                Expanded(
                  child: _total('Total', nota.valorTotal ?? 0, destaque: true),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _linha(String label, String valor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(label,
                style: const TextStyle(
                    fontSize: 12.5, color: AppColors.mutedForeground)),
          ),
          Expanded(
            child: Text(valor, style: const TextStyle(fontSize: 12.5)),
          ),
        ],
      ),
    );
  }

  Widget _total(String label, double valor, {bool destaque = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 11, color: AppColors.mutedForeground)),
        Text(
          Formatters.moeda(valor),
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: destaque ? AppColors.primary : AppColors.foreground,
          ),
        ),
      ],
    );
  }
}
