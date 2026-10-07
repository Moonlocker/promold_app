import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../providers/auth_providers.dart';
import '../../../providers/pecas_catalogo_providers.dart';
import '../../../providers/sistema_providers.dart';
import '../../../providers/supabase_providers.dart';

/// Catálogo de orçamentos: Composições e Insumos.
class OrcamentosCatalogoScreen extends StatelessWidget {
  const OrcamentosCatalogoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Catálogo de Orçamentos'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Composições'),
              Tab(text: 'Insumos'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [_ComposicoesTab(), _InsumosTab()],
        ),
      ),
    );
  }
}

// ============================================================ Composições

class _ComposicoesTab extends ConsumerWidget {
  const _ComposicoesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(orcamentoCatalogoProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: ref.podeCriar('orcamentos')
          ? FloatingActionButton.extended(
              onPressed: () => _form(context, ref),
              icon: const Icon(Icons.add),
              label: const Text('Nova Composição'),
            )
          : null,
      body: async.when(
        loading: () => const LoadingView(),
        error: (e, _) => Center(child: Text('Erro: $e')),
        data: (composicoes) {
          if (composicoes.isEmpty) {
            return const EmptyState(
              icon: Icons.layers_outlined,
              title: 'Nenhuma composição',
              message: 'Cadastre composições com seus insumos.',
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(orcamentoCatalogoProvider),
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 96),
              itemCount: composicoes.length,
              itemBuilder: (context, i) =>
                  _ComposicaoTile(composicao: composicoes[i]),
            ),
          );
        },
      ),
    );
  }

  Future<void> _form(
    BuildContext context,
    WidgetRef ref, {
    Map<String, dynamic>? composicao,
  }) async {
    final nome = TextEditingController(text: (composicao?['nome'] ?? '') as String);
    final unidade =
        TextEditingController(text: (composicao?['unidade'] ?? 'un') as String);
    final descricao = TextEditingController(
        text: (composicao?['descricao'] ?? '') as String? ?? '');
    String? pecaId = composicao?['peca_catalogo_id'] as String?;
    final pecas = ref.read(pecasCatalogoListProvider).value ?? const [];

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
              20, 16, 20, 20 + MediaQuery.of(context).viewInsets.bottom + MediaQuery.of(context).padding.bottom),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(composicao == null
                        ? 'Nova composição'
                        : 'Editar composição',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 14),
                DropdownButtonFormField<String?>(
                  initialValue: pecaId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                      labelText: 'Vincular a peça do catálogo (opcional)'),
                  items: [
                    const DropdownMenuItem<String?>(
                        value: null, child: Text('Nenhuma')),
                    ...pecas.map((p) => DropdownMenuItem<String?>(
                          value: p.id,
                          child: Text(p.nome, overflow: TextOverflow.ellipsis),
                        )),
                  ],
                  onChanged: (v) {
                    setSheet(() {
                      pecaId = v;
                      if (v != null) {
                        final p = pecas.where((x) => x.id == v).firstOrNull;
                        if (p != null && nome.text.trim().isEmpty) {
                          nome.text = p.nome;
                        }
                      }
                    });
                  },
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: nome,
                  enabled: pecaId == null,
                  decoration: const InputDecoration(labelText: 'Nome *'),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: unidade,
                        decoration: const InputDecoration(labelText: 'Unidade'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: descricao,
                        decoration:
                            const InputDecoration(labelText: 'Descrição'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                FilledButton(
                  onPressed: () async {
                    if ((pecaId == null) && nome.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Informe o nome')),
                      );
                      return;
                    }
                    await ref
                        .read(orcamentoComposicoesRepositoryProvider)
                        .saveComposicao({
                      'nome': nome.text.trim(),
                      'unidade': unidade.text.trim(),
                      'descricao':
                          descricao.text.trim().isEmpty ? null : descricao.text.trim(),
                      'peca_catalogo_id': pecaId,
                    }, id: composicao?['id'] as String?);
                    ref.invalidate(orcamentoCatalogoProvider);
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
    nome.dispose();
    unidade.dispose();
    descricao.dispose();
    if (ok == true && context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Composição salva')));
    }
  }
}

class _ComposicaoTile extends ConsumerWidget {
  const _ComposicaoTile({required this.composicao});

  final Map<String, dynamic> composicao;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = composicao['id'] as String;
    final nome = (composicao['nome'] as String?) ?? 'Composição';
    final unidade = (composicao['unidade'] as String?) ?? 'un';
    final custo = (composicao['custo_total'] as num?)?.toDouble() ?? 0;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        title: Text(nome, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          '$unidade · ${Formatters.moeda(custo)}',
          style: const TextStyle(fontSize: 12.5),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(Formatters.moeda(custo),
                style: const TextStyle(fontWeight: FontWeight.w600)),
            if (ref.podeEditar('orcamentos'))
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, size: 20),
                onSelected: (v) async {
                  if (v == 'editar') {
                    await _ComposicoesTab()._form(context, ref,
                        composicao: composicao);
                  } else if (v == 'excluir') {
                    await _confirmarExclusao(context, ref, id, nome);
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'editar', child: Text('Editar')),
                  PopupMenuItem(
                    value: 'excluir',
                    child: Text('Excluir',
                        style: TextStyle(color: AppColors.destructive)),
                  ),
                ],
              ),
          ],
        ),
        children: [_ComposicaoInsumos(composicaoId: id)],
      ),
    );
  }

  Future<void> _confirmarExclusao(
    BuildContext context,
    WidgetRef ref,
    String id,
    String nome,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir composição'),
        content: Text('Excluir "$nome" e seus insumos?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style:
                FilledButton.styleFrom(backgroundColor: AppColors.destructive),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref
        .read(orcamentoComposicoesRepositoryProvider)
        .deleteComposicaoCatalogo(id);
    ref.invalidate(orcamentoCatalogoProvider);
  }
}

class _ComposicaoInsumos extends ConsumerWidget {
  const _ComposicaoInsumos({required this.composicaoId});

  final String composicaoId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(composicaoCatalogoInsumosProvider(composicaoId));
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          async.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => Text('Erro: $e'),
            data: (insumos) {
              if (insumos.isEmpty) {
                return const Text('Nenhum insumo nesta composição.',
                    style: TextStyle(
                        fontSize: 12.5, color: AppColors.mutedForeground));
              }
              return Column(
                children: insumos.map((it) {
                  final ins = it['insumos'];
                  final nomeIns =
                      ins is Map ? (ins['nome'] as String? ?? '—') : '—';
                  final un = ins is Map ? (ins['unidade'] as String? ?? '') : '';
                  final qtd = (it['quantidade'] as num?)?.toDouble() ?? 0;
                  return Dismissible(
                    key: ValueKey(it['id'] as String),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      alignment: Alignment.centerRight,
                      color: AppColors.destructive.withValues(alpha: 0.15),
                      padding: const EdgeInsets.only(right: 16),
                      child: const Icon(Icons.delete_outline,
                          color: AppColors.destructive),
                    ),
                    onDismissed: (_) async {
                      await ref
                          .read(orcamentoComposicoesRepositoryProvider)
                          .deleteComposicaoInsumo(it['id'] as String);
                      ref.invalidate(composicaoCatalogoInsumosProvider(composicaoId));
                      ref.invalidate(orcamentoCatalogoProvider);
                    },
                    child: ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(nomeIns,
                          style: const TextStyle(fontSize: 13)),
                      subtitle: Text(
                        '${Formatters.numero(qtd, 3)} $un',
                        style: const TextStyle(fontSize: 11.5),
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
          if (ref.podeEditar('orcamentos'))
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => _addInsumo(context, ref),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Adicionar insumo'),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _addInsumo(BuildContext context, WidgetRef ref) async {
    final todos =
        await ref.read(orcamentoComposicoesRepositoryProvider).listInsumos();
    if (!context.mounted) return;
    String? insumoId;
    final qtd = TextEditingController(text: '1');
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
              20, 16, 20, 20 + MediaQuery.of(context).viewInsets.bottom + MediaQuery.of(context).padding.bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Adicionar insumo',
                  style:
                      TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: insumoId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Insumo *'),
                items: todos
                    .map((i) => DropdownMenuItem(
                          value: i['id'] as String,
                          child: Text(
                            '${i['nome']} (${i['unidade'] ?? ''})',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ))
                    .toList(),
                onChanged: (v) => setSheet(() => insumoId = v),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: qtd,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Quantidade'),
              ),
              const SizedBox(height: 18),
              FilledButton(
                onPressed: () async {
                  if (insumoId == null) return;
                  final q =
                      double.tryParse(qtd.text.replaceAll(',', '.')) ?? 1;
                  final insumo =
                      todos.where((x) => x['id'] == insumoId).firstOrNull;
                  final preco =
                      (insumo?['preco'] as num?)?.toDouble() ?? 0;
                  await ref
                      .read(orcamentoComposicoesRepositoryProvider)
                      .addComposicaoInsumo(composicaoId, {
                    'insumo_id': insumoId,
                    'quantidade': q,
                    'custo_total': q * preco,
                  });
                  ref.invalidate(
                      composicaoCatalogoInsumosProvider(composicaoId));
                  ref.invalidate(orcamentoCatalogoProvider);
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
    if (ok == true && context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Insumo adicionado')));
    }
  }
}

// ================================================================ Insumos

class _InsumosTab extends ConsumerWidget {
  const _InsumosTab();

  static const _tipos = ['material', 'equipamento', 'taxa', 'mao_de_obra', 'servico'];
  static const _parametros = {
    '': 'Nenhum (quantidade fixa)',
    'comprimento': 'Comprimento',
    'volume_total': 'Vol. m³',
    'kg_aco_total': 'Taxa Aço',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(orcamentoCatalogoInsumosProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: ref.podeCriar('orcamentos')
          ? FloatingActionButton.extended(
              onPressed: () => _form(context, ref),
              icon: const Icon(Icons.add),
              label: const Text('Novo Insumo'),
            )
          : null,
      body: async.when(
        loading: () => const LoadingView(),
        error: (e, _) => Center(child: Text('Erro: $e')),
        data: (insumos) {
          if (insumos.isEmpty) {
            return const EmptyState(
              icon: Icons.category_outlined,
              title: 'Nenhum insumo',
              message: 'Cadastre insumos do catálogo.',
            );
          }
          return RefreshIndicator(
            onRefresh: () async =>
                ref.invalidate(orcamentoCatalogoInsumosProvider),
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 96),
              itemCount: insumos.length,
              itemBuilder: (context, i) {
                final it = insumos[i];
                final nome = (it['nome'] as String?) ?? 'Insumo';
                final tipo = (it['tipo'] as String?) ?? 'material';
                final unidade = (it['unidade'] as String?) ?? 'un';
                final preco = (it['preco'] as num?)?.toDouble() ?? 0;
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    title: Text(nome,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text('$tipo · $unidade',
                        style: const TextStyle(fontSize: 12)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(Formatters.moeda(preco),
                            style:
                                const TextStyle(fontWeight: FontWeight.w600)),
                        if (ref.podeEditar('orcamentos'))
                          PopupMenuButton<String>(
                            icon: const Icon(Icons.more_vert, size: 20),
                            onSelected: (v) async {
                              if (v == 'editar') {
                                await _form(context, ref, insumo: it);
                              } else if (v == 'excluir') {
                                await ref
                                    .read(orcamentoComposicoesRepositoryProvider)
                                    .deleteInsumoCatalogo(it['id'] as String);
                                ref.invalidate(
                                    orcamentoCatalogoInsumosProvider);
                              }
                            },
                            itemBuilder: (_) => const [
                              PopupMenuItem(
                                  value: 'editar', child: Text('Editar')),
                              PopupMenuItem(
                                value: 'excluir',
                                child: Text('Excluir',
                                    style: TextStyle(
                                        color: AppColors.destructive)),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Future<void> _form(
    BuildContext context,
    WidgetRef ref, {
    Map<String, dynamic>? insumo,
  }) async {
    final nome = TextEditingController(text: (insumo?['nome'] ?? '') as String);
    final codigo =
        TextEditingController(text: (insumo?['codigo'] ?? '') as String? ?? '');
    final unidade =
        TextEditingController(text: (insumo?['unidade'] ?? 'un') as String);
    final preco = TextEditingController(
        text: ((insumo?['preco'] as num?)?.toDouble() ?? 0).toStringAsFixed(2));
    final descricao = TextEditingController(
        text: (insumo?['descricao'] ?? '') as String? ?? '');
    var tipo = (insumo?['tipo'] as String?) ?? 'material';
    var parametro = (insumo?['parametro_vinculado'] as String?) ?? '';

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
              20, 16, 20, 20 + MediaQuery.of(context).viewInsets.bottom + MediaQuery.of(context).padding.bottom),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(insumo == null ? 'Novo insumo' : 'Editar insumo',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 14),
                TextField(
                  controller: nome,
                  decoration: const InputDecoration(labelText: 'Nome *'),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: tipo,
                  decoration: const InputDecoration(labelText: 'Tipo *'),
                  items: _tipos
                      .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                      .toList(),
                  onChanged: (v) => setSheet(() => tipo = v ?? 'material'),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: codigo,
                        decoration: const InputDecoration(labelText: 'Código'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: unidade,
                        decoration: const InputDecoration(labelText: 'Unidade'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: preco,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration:
                      const InputDecoration(labelText: 'Preço (R\$)'),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: parametro,
                  decoration:
                      const InputDecoration(labelText: 'Parâmetro vinculado'),
                  items: _parametros.entries
                      .map((e) =>
                          DropdownMenuItem(value: e.key, child: Text(e.value)))
                      .toList(),
                  onChanged: (v) => setSheet(() => parametro = v ?? ''),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: descricao,
                  decoration: const InputDecoration(labelText: 'Descrição'),
                ),
                const SizedBox(height: 18),
                FilledButton(
                  onPressed: () async {
                    if (nome.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Informe o nome')),
                      );
                      return;
                    }
                    await ref
                        .read(orcamentoComposicoesRepositoryProvider)
                        .saveInsumo({
                      'nome': nome.text.trim(),
                      'tipo': tipo,
                      'codigo': codigo.text.trim().isEmpty
                          ? null
                          : codigo.text.trim(),
                      'unidade': unidade.text.trim(),
                      'preco':
                          double.tryParse(preco.text.replaceAll(',', '.')) ?? 0,
                      'parametro_vinculado': parametro.isEmpty ? null : parametro,
                      'descricao': descricao.text.trim().isEmpty
                          ? null
                          : descricao.text.trim(),
                    }, id: insumo?['id'] as String?);
                    ref.invalidate(orcamentoCatalogoInsumosProvider);
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
    nome.dispose();
    codigo.dispose();
    unidade.dispose();
    preco.dispose();
    descricao.dispose();
    if (ok == true && context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Insumo salvo')));
    }
  }
}
