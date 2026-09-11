import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/auth_providers.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/simple_form_sheet.dart';
import '../../../models/categoria_financeira.dart';
import '../../../providers/cadastros_providers.dart';
import '../../../providers/supabase_providers.dart';

/// MÃ³dulo Categorias Financeiras.
class CategoriasFinanceirasScreen extends ConsumerStatefulWidget {
  const CategoriasFinanceirasScreen({super.key});

  @override
  ConsumerState<CategoriasFinanceirasScreen> createState() =>
      _CategoriasFinanceirasScreenState();
}

class _CategoriasFinanceirasScreenState
    extends ConsumerState<CategoriasFinanceirasScreen> {
  String _busca = '';

  @override
  Widget build(BuildContext context) {
    final categoriasAsync = ref.watch(categoriasFinanceirasListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Categorias Financeiras')),
      floatingActionButton: ref.podeCriar('financeiro-categorias')
          ? FloatingActionButton.extended(
              onPressed: () => _abrirForm(),
              icon: const Icon(Icons.add),
              label: const Text('Nova'),
            )
          : null,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
              onChanged: (v) => setState(() => _busca = v),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search, size: 20),
                hintText: 'Buscar categoria...',
                isDense: true,
              ),
            ),
          ),
          Expanded(
            child: categoriasAsync.when(
              loading: () => const LoadingView(message: 'Carregando...'),
              error: (e, _) => Center(child: Text('Erro: $e')),
              data: (categorias) {
                final filtradas = categorias
                    .where((c) =>
                        c.nome.toLowerCase().contains(_busca.toLowerCase()))
                    .toList();
                if (filtradas.isEmpty) {
                  return const EmptyState(
                    icon: Icons.sell_outlined,
                    title: 'Nenhuma categoria',
                    message: 'Cadastre categorias para classificar lanÃ§amentos.',
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async =>
                      ref.invalidate(categoriasFinanceirasListProvider),
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                    itemCount: filtradas.length,
                    itemBuilder: (context, i) => _CategoriaCard(
                      categoria: filtradas[i],
                      onChanged: () =>
                          ref.invalidate(categoriasFinanceirasListProvider),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _abrirForm({CategoriaFinanceira? categoria}) async {
    final result = await showSimpleFormSheet(
      context,
      title: categoria == null ? 'Nova Categoria' : 'Editar Categoria',
      submitLabel: categoria == null ? 'Cadastrar' : 'Salvar',
      fields: [
        SimpleField(
          key: 'nome',
          label: 'Nome *',
          initial: categoria?.nome,
          required: true,
        ),
        SimpleField(
          key: 'tipo',
          label: 'Tipo',
          initial: categoria?.tipo ?? 'ambos',
          options: const [
            SimpleOption('receita', 'Receita'),
            SimpleOption('despesa', 'Despesa'),
            SimpleOption('ambos', 'Ambos'),
          ],
        ),
      ],
    );
    if (result == null) return;
    final repo = ref.read(financeiroCadastrosRepositoryProvider);
    final payload = {
      'nome': result['nome'],
      'tipo': result['tipo'],
      'categoria_pai_id': null,
    };
    if (categoria == null) {
      await repo.createCategoria(payload);
    } else {
      await repo.updateCategoria(categoria.id, payload);
    }
    ref.invalidate(categoriasFinanceirasListProvider);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Categoria salva!')),
      );
    }
  }
}

class _CategoriaCard extends ConsumerWidget {
  const _CategoriaCard({required this.categoria, required this.onChanged});

  final CategoriaFinanceira categoria;
  final VoidCallback onChanged;

  Color get _cor => switch (categoria.tipo) {
        'receita' => AppColors.success,
        'despesa' => AppColors.destructive,
        _ => AppColors.primary,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        title: Text(
          categoria.nome,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: categoria.ativa
                ? AppColors.foreground
                : AppColors.mutedForeground,
          ),
        ),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _cor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(Icons.sell_outlined, size: 18, color: _cor),
        ),
        subtitle: Text(categoria.tipoLabel),
        trailing: (ref.podeEditar('financeiro-categorias') ||
                ref.podeExcluir('financeiro-categorias'))
            ? PopupMenuButton<String>(
                onSelected: (v) => _acao(context, ref, v),
                itemBuilder: (_) => [
                  if (ref.podeEditar('financeiro-categorias'))
                    const PopupMenuItem(value: 'editar', child: Text('Editar')),
                  if (ref.podeEditar('financeiro-categorias'))
                    PopupMenuItem(
                      value: 'toggle',
                      child: Text(categoria.ativa ? 'Desativar' : 'Ativar'),
                    ),
                  if (ref.podeExcluir('financeiro-categorias'))
                    const PopupMenuItem(
                      value: 'excluir',
                      child: Text('Excluir',
                          style: TextStyle(color: AppColors.destructive)),
                    ),
                ],
              )
            : null,
      ),
    );
  }

  Future<void> _acao(BuildContext context, WidgetRef ref, String acao) async {
    final repo = ref.read(financeiroCadastrosRepositoryProvider);
    switch (acao) {
      case 'editar':
        final result = await showSimpleFormSheet(
          context,
          title: 'Editar Categoria',
          fields: [
            SimpleField(
                key: 'nome', label: 'Nome *', initial: categoria.nome, required: true),
            SimpleField(
              key: 'tipo',
              label: 'Tipo',
              initial: categoria.tipo,
              options: const [
                SimpleOption('receita', 'Receita'),
                SimpleOption('despesa', 'Despesa'),
                SimpleOption('ambos', 'Ambos'),
              ],
            ),
          ],
        );
        if (result == null) return;
        await repo.updateCategoria(categoria.id, {
          'nome': result['nome'],
          'tipo': result['tipo'],
          'categoria_pai_id': null,
        });
        onChanged();
      case 'toggle':
        await repo.updateCategoria(categoria.id, {'ativa': !categoria.ativa});
        onChanged();
      case 'excluir':
        final uso = await repo.countUsoCategoria(categoria.id);
        if (!context.mounted) return;
        if (uso > 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content:
                  Text('Em uso em $uso lanÃ§amento(s). NÃ£o Ã© possÃ­vel excluir.'),
            ),
          );
          return;
        }
        final confirmar = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Excluir categoria'),
            content: Text('Excluir "${categoria.nome}"?'),
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
        if (confirmar == true) {
          await repo.deleteCategoria(categoria.id);
          onChanged();
        }
    }
  }
}
