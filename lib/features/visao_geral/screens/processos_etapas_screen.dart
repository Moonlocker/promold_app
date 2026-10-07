import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../models/processo_etapa.dart';
import '../../../providers/obra_providers.dart';
import '../../../providers/supabase_providers.dart';

/// Cadastro de processos e etapas manuais (matriz do Status Geral).
class ProcessosEtapasScreen extends ConsumerWidget {
  const ProcessosEtapasScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final processosAsync = ref.watch(processosEtapasProvider);
    final itensAsync = ref.watch(processosEtapasItensProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Processos e Etapas'),
        actions: [
          IconButton(
            tooltip: 'Novo processo',
            icon: const Icon(Icons.add),
            onPressed: () => _formProcesso(context, ref),
          ),
        ],
      ),
      body: processosAsync.when(
        loading: () => const LoadingView(),
        error: (e, _) => Center(child: Text('Erro: $e')),
        data: (processos) {
          if (processos.isEmpty) {
            return const EmptyState(
              icon: Icons.account_tree_outlined,
              title: 'Nenhum processo',
              message: 'Cadastre processos e etapas para acompanhar na matriz.',
            );
          }
          final itens = itensAsync.value ?? const <ProcessoEtapaItem>[];
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(processosEtapasProvider);
              ref.invalidate(processosEtapasItensProvider);
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 32),
              children: processos.map((p) {
                final doProcesso =
                    itens.where((i) => i.processoId == p.id).toList();
                return _ProcessoCard(
                  processo: p,
                  itens: doProcesso,
                );
              }).toList(),
            ),
          );
        },
      ),
    );
  }

  Future<void> _formProcesso(
    BuildContext context,
    WidgetRef ref, {
    ProcessoEtapa? processo,
  }) async {
    final nome = TextEditingController(text: processo?.nome ?? '');
    final cor = TextEditingController(text: processo?.cor ?? '#94a3b8');
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(
            20, 16, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(processo == null ? 'Novo processo' : 'Editar processo',
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 14),
            TextField(
                controller: nome,
                decoration: const InputDecoration(labelText: 'Nome *')),
            const SizedBox(height: 10),
            TextField(
                controller: cor,
                decoration:
                    const InputDecoration(labelText: 'Cor (hex, ex: #3B82F6)')),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Salvar'),
            ),
          ],
        ),
      ),
    );
    if (ok == true && nome.text.trim().isNotEmpty) {
      final atuais = ref.read(processosEtapasProvider).value ?? const [];
      await ref.read(processosRepositoryProvider).saveProcesso({
        'nome': nome.text.trim(),
        'cor': cor.text.trim().isEmpty ? '#94a3b8' : cor.text.trim(),
        'ordem': atuais.length,
      }, id: processo?.id);
      ref.invalidate(processosEtapasProvider);
    }
    nome.dispose();
    cor.dispose();
  }
}

class _ProcessoCard extends ConsumerWidget {
  const _ProcessoCard({required this.processo, required this.itens});

  final ProcessoEtapa processo;
  final List<ProcessoEtapaItem> itens;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ExpansionTile(
        leading: Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: _hex(processo.cor),
            shape: BoxShape.circle,
          ),
        ),
        title: Text(processo.nome,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text('${itens.length} etapa(s)',
            style: const TextStyle(fontSize: 12)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'Adicionar etapa',
              icon: const Icon(Icons.add, size: 20),
              onPressed: () => _formItem(context, ref),
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, size: 20),
              onSelected: (v) async {
                if (v == 'editar') {
                  await ProcessosEtapasScreen()._formProcesso(context, ref,
                      processo: processo);
                } else if (v == 'excluir') {
                  await ref
                      .read(processosRepositoryProvider)
                      .deleteProcesso(processo.id);
                  ref.invalidate(processosEtapasProvider);
                  ref.invalidate(processosEtapasItensProvider);
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'editar', child: Text('Editar')),
                PopupMenuItem(
                    value: 'excluir',
                    child: Text('Excluir',
                        style: TextStyle(color: AppColors.destructive))),
              ],
            ),
          ],
        ),
        children: [
          if (itens.isEmpty)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text('Nenhuma etapa.',
                  style: TextStyle(
                      fontSize: 12.5, color: AppColors.mutedForeground)),
            )
          else
            ...itens.map((it) => ListTile(
                  dense: true,
                  title: Text(it.nome, style: const TextStyle(fontSize: 13.5)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        onPressed: () => _formItem(context, ref, item: it),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline,
                            size: 18, color: AppColors.destructive),
                        onPressed: () async {
                          await ref
                              .read(processosRepositoryProvider)
                              .deleteItem(it.id);
                          ref.invalidate(processosEtapasItensProvider);
                        },
                      ),
                    ],
                  ),
                )),
        ],
      ),
    );
  }

  Future<void> _formItem(
    BuildContext context,
    WidgetRef ref, {
    ProcessoEtapaItem? item,
  }) async {
    final nome = TextEditingController(text: item?.nome ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(item == null ? 'Nova etapa' : 'Editar etapa'),
        content: TextField(
          controller: nome,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Nome da etapa *'),
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
    if (ok == true && nome.text.trim().isNotEmpty) {
      final todos = ref.read(processosEtapasItensProvider).value ?? const [];
      final qtd = todos.where((i) => i.processoId == processo.id).length;
      await ref.read(processosRepositoryProvider).saveItem({
        'processo_id': processo.id,
        'nome': nome.text.trim(),
        'ordem': item?.ordem ?? qtd,
      }, id: item?.id);
      ref.invalidate(processosEtapasItensProvider);
    }
    nome.dispose();
  }

  static Color _hex(String hex) {
    var h = hex.replaceAll('#', '');
    if (h.length == 3) {
      h = h.split('').map((c) => '$c$c').join();
    }
    if (h.length != 6) return AppColors.mutedForeground;
    final v = int.tryParse(h, radix: 16) ?? 0x94A3B8;
    return Color(0xFF000000 | v);
  }
}
