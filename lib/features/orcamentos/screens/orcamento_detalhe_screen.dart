import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/env.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../models/sistema.dart';
import '../../../providers/auth_providers.dart';
import '../../../providers/pecas_catalogo_providers.dart';
import '../../../providers/sistema_providers.dart';
import '../../../providers/supabase_providers.dart';
import '../../../services/orcamento_pdf_service.dart';
import 'orcamento_etapas_screen.dart';

const _status = ['rascunho', 'enviado', 'aprovado', 'recusado', 'concluido'];

/// Detalhe completo do orçamento: dados, itens, BDI, PDF e link público.
class OrcamentoDetalheScreen extends ConsumerWidget {
  const OrcamentoDetalheScreen({super.key, required this.orcamento});

  final Orcamento orcamento;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orcAsync = ref.watch(orcamentoProvider(orcamento.id));
    final itensAsync = ref.watch(orcamentoItensProvider(orcamento.id));
    final composicoesTotal =
        ref.watch(orcamentoComposicoesTotalProvider(orcamento.id)).value ?? 0;
    final o = orcAsync.value ?? orcamento;

    return Scaffold(
      appBar: AppBar(
        title: Text('Orçamento #${o.numeroOrcamento}'),
        actions: [
          if (ref.podeEditar('orcamentos'))
            IconButton(
              tooltip: 'Etapas e composições',
              onPressed: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => OrcamentoEtapasScreen(orcamento: o),
                  ),
                );
                ref.invalidate(orcamentoComposicoesTotalProvider(o.id));
                await _recalcularTotal(ref, o);
              },
              icon: const Icon(Icons.layers_outlined),
            ),
          if (ref.podeEditar('orcamentos'))
            IconButton(
              tooltip: 'Editar dados',
              onPressed: () => _editarDados(context, ref, o),
              icon: const Icon(Icons.edit_outlined),
            ),
          IconButton(
            tooltip: 'Gerar PDF',
            onPressed: () => _pdf(context, ref, o),
            icon: const Icon(Icons.picture_as_pdf_outlined),
          ),
        ],
      ),
      body: itensAsync.when(
        loading: () => const LoadingView(),
        error: (e, _) => Center(child: Text('Erro: $e')),
        data: (itens) {
          final subtotalItens = itens.fold<double>(0, (a, it) {
            final qtd = (it['quantidade'] as num?)?.toDouble() ?? 0;
            final unit = (it['custo_unitario'] as num?)?.toDouble() ?? 0;
            return a +
                ((it['custo_total'] as num?)?.toDouble() ?? (qtd * unit));
          });
          final subtotal = subtotalItens + composicoesTotal;
          final bdi = o.bdiAtivo
              ? subtotal * ((o.percentualAjuste ?? 0) / 100)
              : 0.0;
          final total = subtotal + bdi;

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _linha('Cliente', o.cliente),
                      if (o.endereco != null) _linha('Endereço', o.endereco!),
                      if (o.contatoResponsavel != null)
                        _linha('Contato', o.contatoResponsavel!),
                      if (o.telefoneContato != null)
                        _linha('Telefone', o.telefoneContato!),
                      if (o.prazoEstimado != null)
                        _linha('Prazo', o.prazoEstimado!),
                      if (o.dataValidade != null)
                        _linha('Validade', o.dataValidade!),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        initialValue: _status.contains(o.status)
                            ? o.status
                            : _status.first,
                        decoration: const InputDecoration(
                            labelText: 'Status', isDense: true),
                        items: _status
                            .map((s) =>
                                DropdownMenuItem(value: s, child: Text(s)))
                            .toList(),
                        onChanged: (v) async {
                          if (v == null) return;
                          await ref
                              .read(sistemaRepositoryProvider)
                              .updateOrcamento(o.id, {'status': v});
                          ref.invalidate(orcamentoProvider(o.id));
                          ref.invalidate(orcamentosListProvider);
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Expanded(
                    child: Text('Itens',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                  TextButton.icon(
                    onPressed: () => _addItem(context, ref, o),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Adicionar'),
                  ),
                ],
              ),
              if (itens.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('Nenhum item adicionado.',
                        style: TextStyle(color: AppColors.mutedForeground)),
                  ),
                )
              else
                ...itens.map((it) => _ItemCard(
                      item: it,
                      onEdit: () => _addItem(context, ref, o, item: it),
                      onDelete: () async {
                        await ref
                            .read(sistemaRepositoryProvider)
                            .deleteOrcamentoItem(it['id'] as String);
                        ref.invalidate(orcamentoItensProvider(o.id));
                        await _recalcularTotal(ref, o);
                      },
                    )),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _total('Subtotal', subtotal),
                      if (o.bdiAtivo)
                        _total('BDI (${o.percentualAjuste ?? 0}%)', bdi),
                      const Divider(),
                      _total('Total', total, destaque: true),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Column(
                  children: [
                    SwitchListTile(
                      title: const Text('Link público'),
                      subtitle: Text(
                        o.linkPublicoAtivo
                            ? 'Ativo · código ${o.codigoPublico ?? '—'}'
                            : 'Desativado',
                        style: const TextStyle(fontSize: 12.5),
                      ),
                      value: o.linkPublicoAtivo,
                      onChanged: (v) async {
                        await ref.read(sistemaRepositoryProvider).updateOrcamento(
                          o.id,
                          {
                            'link_publico_ativo': v,
                            'codigo_publico': o.codigoPublico ?? _gerarCodigo(),
                          },
                        );
                        ref.invalidate(orcamentoProvider(o.id));
                      },
                    ),
                    if (o.linkPublicoAtivo && Env.webBaseUrl.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final url =
                                '${Env.webBaseUrl}/orcamento-publico/${o.codigoPublico ?? ''}';
                            await Clipboard.setData(ClipboardData(text: url));
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Link copiado')),
                              );
                            }
                          },
                          icon: const Icon(Icons.link, size: 18),
                          label: const Text('Copiar link público'),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  static String _gerarCodigo() {
    final now = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    return now.toUpperCase().padLeft(8, '0').substring(0, 8);
  }

  Future<void> _recalcularTotal(WidgetRef ref, Orcamento o) async {
    final itens =
        await ref.read(sistemaRepositoryProvider).listOrcamentoItens(o.id);
    final subtotalItens = itens.fold<double>(0, (a, it) {
      final qtd = (it['quantidade'] as num?)?.toDouble() ?? 0;
      final unit = (it['custo_unitario'] as num?)?.toDouble() ?? 0;
      return a + ((it['custo_total'] as num?)?.toDouble() ?? (qtd * unit));
    });
    final composicoes = await ref
        .read(orcamentoComposicoesRepositoryProvider)
        .totalOrcamento(o.id);
    final subtotal = subtotalItens + composicoes;
    final bdi =
        o.bdiAtivo ? subtotal * ((o.percentualAjuste ?? 0) / 100) : 0.0;
    await ref
        .read(sistemaRepositoryProvider)
        .updateOrcamento(o.id, {'valor_total': subtotal + bdi});
    ref.invalidate(orcamentoProvider(o.id));
    ref.invalidate(orcamentoComposicoesTotalProvider(o.id));
    ref.invalidate(orcamentosListProvider);
  }

  Future<void> _editarDados(
    BuildContext context,
    WidgetRef ref,
    Orcamento o,
  ) async {
    final cliente = TextEditingController(text: o.cliente);
    final endereco = TextEditingController(text: o.endereco ?? '');
    final contato = TextEditingController(text: o.contatoResponsavel ?? '');
    final telefone = TextEditingController(text: o.telefoneContato ?? '');
    final prazo = TextEditingController(text: o.prazoEstimado ?? '');
    final validade = TextEditingController(text: o.dataValidade ?? '');
    final obs = TextEditingController(text: o.observacoes ?? '');
    final ajuste = TextEditingController(
        text: o.percentualAjuste?.toStringAsFixed(2) ?? '0');
    var bdiAtivo = o.bdiAtivo;

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
              20, 16, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Editar orçamento',
                    style: TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 16),
                TextField(
                    controller: cliente,
                    decoration: const InputDecoration(labelText: 'Cliente *')),
                const SizedBox(height: 10),
                TextField(
                    controller: endereco,
                    decoration: const InputDecoration(labelText: 'Endereço')),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                          controller: contato,
                          decoration:
                              const InputDecoration(labelText: 'Contato')),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                          controller: telefone,
                          decoration:
                              const InputDecoration(labelText: 'Telefone')),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                          controller: prazo,
                          decoration:
                              const InputDecoration(labelText: 'Prazo')),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                          controller: validade,
                          decoration: const InputDecoration(
                              labelText: 'Validade (AAAA-MM-DD)')),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                          controller: ajuste,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          decoration: const InputDecoration(
                              labelText: 'BDI / Ajuste (%)')),
                    ),
                    const SizedBox(width: 8),
                    Switch(
                      value: bdiAtivo,
                      onChanged: (v) => setSheet(() => bdiAtivo = v),
                    ),
                    const Text('BDI'),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                    controller: obs,
                    maxLines: 2,
                    decoration:
                        const InputDecoration(labelText: 'Observações')),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: () async {
                    await ref.read(sistemaRepositoryProvider).updateOrcamento(
                      o.id,
                      {
                        'cliente': cliente.text.trim(),
                        'endereco': _nz(endereco.text),
                        'contato_responsavel': _nz(contato.text),
                        'telefone_contato': _nz(telefone.text),
                        'prazo_estimado': _nz(prazo.text),
                        'data_validade': _nz(validade.text),
                        'observacoes': _nz(obs.text),
                        'percentual_ajuste':
                            double.tryParse(ajuste.text.replaceAll(',', '.')) ?? 0,
                        'bdi_ativo': bdiAtivo,
                      },
                    );
                    ref.invalidate(orcamentoProvider(o.id));
                    ref.invalidate(orcamentosListProvider);
                    await _recalcularTotal(ref, o);
                    if (context.mounted) Navigator.pop(context, true);
                  },
                  child: const Text('Salvar'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    cliente.dispose();
    endereco.dispose();
    contato.dispose();
    telefone.dispose();
    prazo.dispose();
    validade.dispose();
    obs.dispose();
    ajuste.dispose();
    if (ok == true && context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Orçamento atualizado')));
    }
  }

  Future<void> _addItem(
    BuildContext context,
    WidgetRef ref,
    Orcamento o, {
    Map<String, dynamic>? item,
  }) async {
    final pecas = ref.read(pecasCatalogoListProvider).value ?? const [];
    String? pecaId = item?['peca_catalogo_id'] as String?;
    final qtd = TextEditingController(
        text: ((item?['quantidade'] as num?) ?? 1).toString());
    final custo = TextEditingController(
        text: ((item?['custo_unitario'] as num?) ?? 0).toStringAsFixed(2));

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
              20, 16, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(item == null ? 'Adicionar item' : 'Editar item',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: pecaId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Peça *'),
                  items: pecas
                      .map((p) => DropdownMenuItem(
                            value: p.id,
                            child: Text(p.nome,
                                overflow: TextOverflow.ellipsis),
                          ))
                      .toList(),
                  onChanged: (v) => setSheet(() => pecaId = v),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: qtd,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration:
                            const InputDecoration(labelText: 'Quantidade'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: custo,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: const InputDecoration(
                            labelText: 'Custo unitário (R\$)'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: () async {
                    if (pecaId == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Selecione uma peça')),
                      );
                      return;
                    }
                    final q =
                        double.tryParse(qtd.text.replaceAll(',', '.')) ?? 1;
                    final c =
                        double.tryParse(custo.text.replaceAll(',', '.')) ?? 0;
                    final repo = ref.read(sistemaRepositoryProvider);
                    final payload = {
                      'peca_catalogo_id': pecaId,
                      'quantidade': q,
                      'custo_unitario': c,
                      'custo_total': q * c,
                    };
                    if (item == null) {
                      await repo.addOrcamentoItem(o.id, payload);
                    } else {
                      await repo.updateOrcamentoItem(
                          item['id'] as String, payload);
                    }
                    ref.invalidate(orcamentoItensProvider(o.id));
                    await _recalcularTotal(ref, o);
                    if (context.mounted) Navigator.pop(context, true);
                  },
                  child: const Text('Salvar'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    qtd.dispose();
    custo.dispose();
    if (ok == true && context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Item salvo')));
    }
  }

  Future<void> _pdf(BuildContext context, WidgetRef ref, Orcamento o) async {
    final itens =
        await ref.read(sistemaRepositoryProvider).listOrcamentoItens(o.id);
    final composicoesTotal = await ref
        .read(orcamentoComposicoesRepositoryProvider)
        .totalOrcamento(o.id);
    final user = ref.read(appUserProvider).value;
    await OrcamentoPdfService.gerar(
      orcamento: o,
      itens: itens,
      organizacaoNome: user?.organizacao?.nome,
      composicoesTotal: composicoesTotal,
    );
  }

  static String? _nz(String v) => v.trim().isEmpty ? null : v.trim();

  Widget _linha(String label, String valor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: destaque ? 14 : 13,
                  fontWeight:
                      destaque ? FontWeight.w700 : FontWeight.normal)),
          Text(
            Formatters.moeda(valor),
            style: TextStyle(
              fontSize: destaque ? 16 : 13,
              fontWeight: destaque ? FontWeight.w700 : FontWeight.w600,
              color: destaque ? AppColors.primary : AppColors.foreground,
            ),
          ),
        ],
      ),
    );
  }
}

class _ItemCard extends StatelessWidget {
  const _ItemCard({
    required this.item,
    required this.onEdit,
    required this.onDelete,
  });

  final Map<String, dynamic> item;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final peca = item['pecas_catalogo'];
    final nome =
        peca is Map ? (peca['nome'] as String? ?? 'Peça') : 'Peça';
    final qtd = (item['quantidade'] as num?)?.toDouble() ?? 0;
    final unit = (item['custo_unitario'] as num?)?.toDouble() ?? 0;
    final total = (item['custo_total'] as num?)?.toDouble() ?? (qtd * unit);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(nome),
        subtitle: Text(
          '${Formatters.numero(qtd, 0)} × ${Formatters.moeda(unit)}',
          style: const TextStyle(fontSize: 12.5),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(Formatters.moeda(total),
                style: const TextStyle(fontWeight: FontWeight.w600)),
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 18),
              onPressed: onEdit,
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline,
                  size: 18, color: AppColors.destructive),
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}
