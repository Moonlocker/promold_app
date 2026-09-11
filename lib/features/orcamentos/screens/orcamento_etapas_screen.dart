import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../models/sistema.dart';
import '../../../providers/sistema_providers.dart';
import '../../../providers/supabase_providers.dart';

/// Estrutura avançada do orçamento: etapas → composições → insumos.
class OrcamentoEtapasScreen extends ConsumerWidget {
  const OrcamentoEtapasScreen({super.key, required this.orcamento});

  final Orcamento orcamento;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final etapasAsync = ref.watch(orcamentoEtapasProvider(orcamento.id));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Etapas e composições'),
        actions: [
          IconButton(
            tooltip: 'Nova etapa',
            onPressed: () => _novaEtapa(context, ref),
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: etapasAsync.when(
        loading: () => const LoadingView(),
        error: (e, _) => Center(child: Text('Erro: $e')),
        data: (etapas) {
          if (etapas.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Nenhuma etapa cadastrada.',
                      style: TextStyle(color: AppColors.mutedForeground)),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: () => _novaEtapa(context, ref),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Criar etapa'),
                  ),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async =>
                ref.invalidate(orcamentoEtapasProvider(orcamento.id)),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              children: etapas
                  .map((e) => _EtapaCard(
                        orcamento: orcamento,
                        etapa: e,
                        onChanged: () => ref
                            .invalidate(orcamentoEtapasProvider(orcamento.id)),
                      ))
                  .toList(),
            ),
          );
        },
      ),
    );
  }

  Future<void> _novaEtapa(BuildContext context, WidgetRef ref) async {
    final nome = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nova etapa'),
        content: TextField(
          controller: nome,
          decoration: const InputDecoration(labelText: 'Nome da etapa *'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Criar'),
          ),
        ],
      ),
    );
    if (ok == true && nome.text.trim().isNotEmpty) {
      final atuais = ref.read(orcamentoEtapasProvider(orcamento.id)).value ?? [];
      await ref.read(orcamentoComposicoesRepositoryProvider).createEtapa(
            orcamento.id,
            nome.text.trim(),
            atuais.length,
          );
      ref.invalidate(orcamentoEtapasProvider(orcamento.id));
    }
    nome.dispose();
  }
}

class _EtapaCard extends ConsumerWidget {
  const _EtapaCard({
    required this.orcamento,
    required this.etapa,
    required this.onChanged,
  });

  final Orcamento orcamento;
  final Map<String, dynamic> etapa;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final etapaId = etapa['id'] as String;
    final compsAsync = ref.watch(orcamentoComposicoesProvider(etapaId));

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 8, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.layers_outlined,
                    size: 18, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(etapa['nome'] as String? ?? 'Etapa',
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 15)),
                ),
                IconButton(
                  tooltip: 'Adicionar composição',
                  icon: const Icon(Icons.add, size: 20),
                  onPressed: () => _addComposicao(context, ref, etapaId),
                ),
                IconButton(
                  tooltip: 'Excluir etapa',
                  icon: const Icon(Icons.delete_outline,
                      size: 20, color: AppColors.destructive),
                  onPressed: () async {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Excluir etapa'),
                        content: const Text(
                            'A etapa e todas as suas composições serão removidas.'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Cancelar'),
                          ),
                          FilledButton(
                            style: FilledButton.styleFrom(
                                backgroundColor: AppColors.destructive),
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('Excluir'),
                          ),
                        ],
                      ),
                    );
                    if (ok == true) {
                      await ref
                          .read(orcamentoComposicoesRepositoryProvider)
                          .deleteEtapa(etapaId);
                      onChanged();
                    }
                  },
                ),
              ],
            ),
            compsAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(12),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Text('Erro: $e'),
              data: (comps) {
                if (comps.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text('Sem composições nesta etapa.',
                        style: TextStyle(
                            fontSize: 12.5,
                            color: AppColors.mutedForeground)),
                  );
                }
                final subtotal = comps.fold<double>(
                  0,
                  (a, c) => a + ((c['custo_total'] as num?)?.toDouble() ?? 0),
                );
                return Column(
                  children: [
                    ...comps.map((c) => _ComposicaoLinha(
                          orcamento: orcamento,
                          composicao: c,
                          onChanged: onChanged,
                        )),
                    const Divider(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Subtotal da etapa',
                            style: TextStyle(fontWeight: FontWeight.w600)),
                        Text(Formatters.moeda(subtotal),
                            style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary)),
                      ],
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addComposicao(
    BuildContext context,
    WidgetRef ref,
    String etapaId,
  ) async {
    final repo = ref.read(orcamentoComposicoesRepositoryProvider);
    final catalogo = await repo.listCatalogo();
    if (!context.mounted) return;
    if (catalogo.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Nenhuma composição cadastrada no catálogo.')),
      );
      return;
    }
    String? composicaoId;
    final quantidade = TextEditingController(text: '1');
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Adicionar composição',
                  style:
                      TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: composicaoId,
                isExpanded: true,
                decoration:
                    const InputDecoration(labelText: 'Composição *'),
                items: catalogo
                    .map((c) => DropdownMenuItem(
                          value: c['id'] as String,
                          child: Text(c['nome'] as String? ?? 'Composição',
                              overflow: TextOverflow.ellipsis),
                        ))
                    .toList(),
                onChanged: (v) => setSheet(() => composicaoId = v),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: quantidade,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Quantidade'),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () async {
                  if (composicaoId == null) return;
                  final comps = ref
                          .read(orcamentoComposicoesProvider(etapaId))
                          .value ??
                      [];
                  await repo.addComposicaoFromCatalogo(
                    etapaId: etapaId,
                    composicaoId: composicaoId!,
                    ordem: comps.length,
                    quantidade:
                        double.tryParse(quantidade.text.replaceAll(',', '.')) ??
                            1,
                  );
                  if (context.mounted) Navigator.pop(context, true);
                },
                child: const Text('Adicionar'),
              ),
            ],
          ),
        ),
      ),
    );
    quantidade.dispose();
    if (ok == true) onChanged();
  }
}

class _ComposicaoLinha extends ConsumerWidget {
  const _ComposicaoLinha({
    required this.orcamento,
    required this.composicao,
    required this.onChanged,
  });

  final Orcamento orcamento;
  final Map<String, dynamic> composicao;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nomeRel = composicao['composicoes'];
    final nome = nomeRel is Map
        ? (nomeRel['nome'] as String? ?? 'Composição')
        : (composicao['nome'] as String? ?? 'Composição');
    final qtd = (composicao['quantidade'] as num?)?.toDouble() ?? 0;
    final total = (composicao['custo_total'] as num?)?.toDouble() ?? 0;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      title: Text(nome),
      subtitle: Text('Qtd: ${Formatters.numero(qtd, 2)}',
          style: const TextStyle(fontSize: 12)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(Formatters.moeda(total),
              style: const TextStyle(fontWeight: FontWeight.w600)),
          IconButton(
            icon: const Icon(Icons.delete_outline,
                size: 18, color: AppColors.destructive),
            onPressed: () async {
              await ref
                  .read(orcamentoComposicoesRepositoryProvider)
                  .deleteComposicao(composicao['id'] as String);
              onChanged();
            },
          ),
        ],
      ),
      onTap: () => _abrirInsumos(context, ref),
    );
  }

  Future<void> _abrirInsumos(BuildContext context, WidgetRef ref) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _InsumosSheet(
        orcamentoComposicaoId: composicao['id'] as String,
        onChanged: onChanged,
      ),
    );
  }
}

class _InsumosSheet extends ConsumerStatefulWidget {
  const _InsumosSheet({
    required this.orcamentoComposicaoId,
    required this.onChanged,
  });

  final String orcamentoComposicaoId;
  final VoidCallback onChanged;

  @override
  ConsumerState<_InsumosSheet> createState() => _InsumosSheetState();
}

class _InsumosSheetState extends ConsumerState<_InsumosSheet> {
  @override
  Widget build(BuildContext context) {
    final async =
        ref.watch(orcamentoComposicaoInsumosProvider(widget.orcamentoComposicaoId));
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.8,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 4),
            child: Row(
              children: [
                const Expanded(
                  child: Text('Insumos da composição',
                      style: TextStyle(
                          fontSize: 17, fontWeight: FontWeight.w700)),
                ),
                TextButton.icon(
                  onPressed: () => _addInsumo(),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Insumo'),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          Expanded(
            child: async.when(
              loading: () => const LoadingView(),
              error: (e, _) => Center(child: Text('Erro: $e')),
              data: (insumos) {
                if (insumos.isEmpty) {
                  return const Center(
                    child: Text('Sem insumos.',
                        style: TextStyle(color: AppColors.mutedForeground)),
                  );
                }
                return ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: insumos.map((i) {
                    final qtd = (i['quantidade'] as num?)?.toDouble() ?? 0;
                    final preco = (i['preco_unitario'] as num?)?.toDouble() ?? 0;
                    final total = (i['custo_total'] as num?)?.toDouble() ??
                        (qtd * preco);
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        dense: true,
                        title: Text(i['nome_insumo'] as String? ?? 'Insumo'),
                        subtitle: Text(
                          '${Formatters.numero(qtd, 3)} ${i['unidade_insumo'] ?? ''} × ${Formatters.moeda(preco)}',
                          style: const TextStyle(fontSize: 11.5),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(Formatters.moeda(total),
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12.5)),
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, size: 18),
                              onPressed: () => _editarInsumo(i),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline,
                                  size: 18, color: AppColors.destructive),
                              onPressed: () async {
                                await ref
                                    .read(orcamentoComposicoesRepositoryProvider)
                                    .deleteInsumo(i['id'] as String);
                                ref.invalidate(orcamentoComposicaoInsumosProvider(
                                    widget.orcamentoComposicaoId));
                                widget.onChanged();
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _editarInsumo(Map<String, dynamic> insumo) async {
    final qtd = TextEditingController(
        text: ((insumo['quantidade'] as num?) ?? 0).toString());
    final preco = TextEditingController(
        text: ((insumo['preco_unitario'] as num?) ?? 0).toStringAsFixed(2));
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Editar insumo'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: qtd,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Quantidade'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: preco,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Preço unitário'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
    if (ok == true) {
      final q = double.tryParse(qtd.text.replaceAll(',', '.')) ?? 0;
      final p = double.tryParse(preco.text.replaceAll(',', '.')) ?? 0;
      await ref.read(orcamentoComposicoesRepositoryProvider).updateInsumo(
        insumo['id'] as String,
        {'quantidade': q, 'preco_unitario': p, 'custo_total': q * p},
      );
      ref.invalidate(
          orcamentoComposicaoInsumosProvider(widget.orcamentoComposicaoId));
      widget.onChanged();
    }
    qtd.dispose();
    preco.dispose();
  }

  Future<void> _addInsumo() async {
    final repo = ref.read(orcamentoComposicoesRepositoryProvider);
    final insumos = await repo.listInsumos();
    if (!mounted) return;
    String? insumoId;
    final qtd = TextEditingController(text: '1');
    final preco = TextEditingController();
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Adicionar insumo',
                  style:
                      TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: insumoId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Insumo *'),
                items: insumos
                    .map((i) => DropdownMenuItem(
                          value: i['id'] as String,
                          child: Text(i['nome'] as String? ?? 'Insumo',
                              overflow: TextOverflow.ellipsis),
                        ))
                    .toList(),
                onChanged: (v) {
                  setSheet(() {
                    insumoId = v;
                    final sel = insumos
                        .where((i) => i['id'] == v)
                        .firstOrNull;
                    if (sel != null) {
                      preco.text =
                          ((sel['preco'] as num?) ?? 0).toStringAsFixed(2);
                    }
                  });
                },
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: qtd,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      decoration: const InputDecoration(labelText: 'Quantidade'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: preco,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      decoration:
                          const InputDecoration(labelText: 'Preço unitário'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () async {
                  if (insumoId == null) return;
                  final sel =
                      insumos.where((i) => i['id'] == insumoId).firstOrNull;
                  final q =
                      double.tryParse(qtd.text.replaceAll(',', '.')) ?? 0;
                  final p =
                      double.tryParse(preco.text.replaceAll(',', '.')) ?? 0;
                  await repo.addInsumo(widget.orcamentoComposicaoId, {
                    'insumo_id': insumoId,
                    'nome_insumo': sel?['nome'] ?? 'Insumo',
                    'unidade_insumo': sel?['unidade'],
                    'quantidade': q,
                    'preco_unitario': p,
                    'custo_total': q * p,
                  });
                  if (context.mounted) Navigator.pop(context, true);
                },
                child: const Text('Adicionar'),
              ),
            ],
          ),
        ),
      ),
    );
    qtd.dispose();
    preco.dispose();
    if (ok == true) {
      ref.invalidate(
          orcamentoComposicaoInsumosProvider(widget.orcamentoComposicaoId));
      widget.onChanged();
    }
  }
}
