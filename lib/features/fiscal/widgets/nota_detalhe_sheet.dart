import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../models/nota_fiscal.dart';
import '../../../providers/cadastros_providers.dart';
import '../../../providers/financeiro_providers.dart';
import '../../../providers/fiscal_providers.dart';
import '../../../providers/supabase_providers.dart';

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
            if (_podeGerarConta(nota))
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: FilledButton.icon(
                  onPressed: () => _gerarContaReceber(context, ref, nota),
                  icon: const Icon(Icons.receipt_long_outlined),
                  label: const Text('Gerar conta a receber'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  static bool _podeGerarConta(NotaFiscal n) =>
      n.contaReceberId == null && n.status == 'autorizada';

  Future<void> _gerarContaReceber(
    BuildContext context,
    WidgetRef ref,
    NotaFiscal nota,
  ) async {
    final cats =
        ref.read(categoriasFinanceirasListProvider).value ?? const [];
    final desc = TextEditingController(
      text: 'NF ${nota.numero ?? ''}/${nota.serie ?? ''} - '
          '${nota.clienteNome ?? ''}',
    );
    final valor = TextEditingController(
      text: (nota.valorTotal ?? 0).toStringAsFixed(2),
    );
    var vencimento = DateTime.now().add(const Duration(days: 30));
    final obs = TextEditingController(
      text: nota.chaveAcesso != null ? 'Chave NFe: ${nota.chaveAcesso}' : '',
    );
    String? categoriaId;

    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheet) => Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            16,
            20,
            20 +
                MediaQuery.of(context).viewInsets.bottom +
                MediaQuery.of(context).padding.bottom,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Adicionar a Contas a Receber',
                    style: TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                TextField(
                  controller: desc,
                  decoration: const InputDecoration(labelText: 'Descrição *'),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: valor,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration:
                            const InputDecoration(labelText: 'Valor (R\$)'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: vencimento,
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                          );
                          if (picked != null) {
                            setSheet(() => vencimento = picked);
                          }
                        },
                        child: InputDecorator(
                          decoration:
                              const InputDecoration(labelText: 'Vencimento'),
                          child: Text(Formatters.dataBr(vencimento)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (cats.isNotEmpty)
                  DropdownButtonFormField<String>(
                    initialValue: categoriaId,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Categoria'),
                    items: cats
                        .map((c) => DropdownMenuItem(
                              value: c.id,
                              child: Text(c.nome,
                                  overflow: TextOverflow.ellipsis),
                            ))
                        .toList(),
                    onChanged: (v) => setSheet(() => categoriaId = v),
                  ),
                const SizedBox(height: 10),
                TextField(
                  controller: obs,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Observações'),
                ),
                const SizedBox(height: 18),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Criar conta a receber'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (ok != true || !context.mounted) return;

    final v = double.tryParse(valor.text.replaceAll(',', '.'));
    if (v == null || v <= 0 || desc.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe descrição e valor válidos')),
      );
      return;
    }
    try {
      final repo = ref.read(financeiroRepositoryProvider);
      final contaId = await repo.createContaRetornandoId('receber', {
        'descricao': desc.text.trim(),
        'valor': v,
        'data_vencimento': vencimento.toIso8601String().split('T').first,
        'categoria_id': categoriaId,
        'cliente_id': nota.clienteId,
        'cliente': nota.clienteNome,
        'observacoes': obs.text.trim().isEmpty ? null : obs.text.trim(),
        'nota_fiscal_id': nota.id,
        'status': 'pendente',
      });
      await repo.vincularNotaContaReceber(nota.id, contaId);
      ref.invalidate(contasReceberListProvider);
      ref.invalidate(notasFiscaisProvider);
      if (context.mounted) {
        final messenger = ScaffoldMessenger.of(context);
        Navigator.of(context).pop();
        messenger.showSnackBar(const SnackBar(
            content: Text('Conta a receber criada e vinculada à nota')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erro: $e')));
      }
    }
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
