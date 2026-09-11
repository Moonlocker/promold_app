import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../models/estoque.dart';
import '../../../providers/supabase_providers.dart';

/// Abre a folha de gerenciamento de compartimentos de um estoque.
Future<void> showCompartimentosSheet(
  BuildContext context, {
  required Estoque estoque,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _CompartimentosSheet(estoque: estoque),
  );
}

class _CompartimentosSheet extends ConsumerStatefulWidget {
  const _CompartimentosSheet({required this.estoque});

  final Estoque estoque;

  @override
  ConsumerState<_CompartimentosSheet> createState() =>
      _CompartimentosSheetState();
}

class _CompartimentosSheetState extends ConsumerState<_CompartimentosSheet> {
  List<Compartimento> _itens = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() => _loading = true);
    try {
      final itens = await ref
          .read(estoqueRepositoryProvider)
          .listCompartimentos(widget.estoque.id);
      if (mounted) setState(() => _itens = itens);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.8,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text('Compartimentos · ${widget.estoque.nome}',
                        style: const TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w700)),
                  ),
                  IconButton(
                    tooltip: 'Novo compartimento',
                    icon: const Icon(Icons.add),
                    onPressed: () => _form(),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _loading
                  ? const LoadingView()
                  : _itens.isEmpty
                      ? const Center(
                          child: Text('Nenhum compartimento cadastrado.',
                              style: TextStyle(
                                  color: AppColors.mutedForeground)),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _itens.length,
                          itemBuilder: (context, i) {
                            final c = _itens[i];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                leading: Icon(
                                  c.ocupado
                                      ? Icons.inventory_2
                                      : Icons.inventory_2_outlined,
                                  color: c.ocupado
                                      ? AppColors.warning
                                      : AppColors.mutedForeground,
                                ),
                                title: Text(c.nome,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600)),
                                subtitle: Text(
                                  [
                                    if ((c.descricao ?? '').isNotEmpty)
                                      c.descricao!,
                                    c.ocupado ? 'Ocupado' : 'Livre',
                                  ].join(' · '),
                                  style: const TextStyle(fontSize: 12),
                                ),
                                trailing: PopupMenuButton<String>(
                                  onSelected: (v) async {
                                    final repo = ref.read(
                                        estoqueRepositoryProvider);
                                    switch (v) {
                                      case 'editar':
                                        await _form(compartimento: c);
                                      case 'toggle':
                                        await repo.updateCompartimento(
                                            c.id, {'ocupado': !c.ocupado});
                                        await _carregar();
                                      case 'excluir':
                                        await repo.deleteCompartimento(c.id);
                                        await _carregar();
                                    }
                                  },
                                  itemBuilder: (_) => [
                                    const PopupMenuItem(
                                        value: 'editar',
                                        child: Text('Editar')),
                                    PopupMenuItem(
                                      value: 'toggle',
                                      child: Text(c.ocupado
                                          ? 'Marcar como livre'
                                          : 'Marcar como ocupado'),
                                    ),
                                    const PopupMenuItem(
                                      value: 'excluir',
                                      child: Text('Excluir',
                                          style: TextStyle(
                                              color: AppColors.destructive))),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _form({Compartimento? compartimento}) async {
    final nome = TextEditingController(text: compartimento?.nome ?? '');
    final descricao =
        TextEditingController(text: compartimento?.descricao ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
            compartimento == null ? 'Novo compartimento' : 'Editar compartimento'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nome,
              decoration: const InputDecoration(labelText: 'Nome *'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: descricao,
              decoration: const InputDecoration(labelText: 'Descrição'),
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
    if (ok == true && nome.text.trim().isNotEmpty) {
      final repo = ref.read(estoqueRepositoryProvider);
      final payload = {
        'nome': nome.text.trim(),
        'descricao':
            descricao.text.trim().isEmpty ? null : descricao.text.trim(),
      };
      if (compartimento == null) {
        await repo.createCompartimento(widget.estoque.id, payload);
      } else {
        await repo.updateCompartimento(compartimento.id, payload);
      }
      await _carregar();
    }
    nome.dispose();
    descricao.dispose();
  }
}
