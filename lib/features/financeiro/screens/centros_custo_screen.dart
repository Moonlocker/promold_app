import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/auth_providers.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/simple_form_sheet.dart';
import '../../../models/centro_custo.dart';
import '../../../providers/cadastros_providers.dart';
import '../../../providers/supabase_providers.dart';

/// MÃ³dulo Centros de Custo (financeiro).
class CentrosCustoScreen extends ConsumerStatefulWidget {
  const CentrosCustoScreen({super.key});

  @override
  ConsumerState<CentrosCustoScreen> createState() => _CentrosCustoScreenState();
}

class _CentrosCustoScreenState extends ConsumerState<CentrosCustoScreen> {
  String _busca = '';

  @override
  Widget build(BuildContext context) {
    final centrosAsync = ref.watch(centrosCustoListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Centros de Custo')),
      floatingActionButton: ref.podeCriar('financeiro-centros-custo')
          ? FloatingActionButton.extended(
              onPressed: () => _abrirForm(),
              icon: const Icon(Icons.add),
              label: const Text('Novo'),
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
                hintText: 'Buscar centro de custo...',
                isDense: true,
              ),
            ),
          ),
          Expanded(
            child: centrosAsync.when(
              loading: () => const LoadingView(message: 'Carregando...'),
              error: (e, _) => Center(child: Text('Erro: $e')),
              data: (centros) {
                final filtrados = centros
                    .where((c) =>
                        c.nome.toLowerCase().contains(_busca.toLowerCase()) ||
                        (c.descricao ?? '')
                            .toLowerCase()
                            .contains(_busca.toLowerCase()))
                    .toList();
                if (filtrados.isEmpty) {
                  return const EmptyState(
                    icon: Icons.flag_outlined,
                    title: 'Nenhum centro de custo',
                    message:
                        'Cadastre centros para organizar receitas e despesas.',
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async =>
                      ref.invalidate(centrosCustoListProvider),
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                    itemCount: filtrados.length,
                    itemBuilder: (context, i) => _CentroCard(
                      centro: filtrados[i],
                      onChanged: () => ref.invalidate(centrosCustoListProvider),
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

  Future<void> _abrirForm({CentroCusto? centro}) async {
    final result = await showSimpleFormSheet(
      context,
      title: centro == null ? 'Novo Centro de Custo' : 'Editar Centro de Custo',
      submitLabel: centro == null ? 'Cadastrar' : 'Salvar',
      fields: [
        SimpleField(
          key: 'nome',
          label: 'Nome *',
          initial: centro?.nome,
          required: true,
        ),
        SimpleField(
          key: 'descricao',
          label: 'DescriÃ§Ã£o',
          initial: centro?.descricao,
          maxLines: 3,
        ),
      ],
    );
    if (result == null) return;
    final repo = ref.read(financeiroCadastrosRepositoryProvider);
    final payload = {
      'nome': result['nome'],
      'descricao': (result['descricao'] ?? '').isEmpty ? null : result['descricao'],
    };
    if (centro == null) {
      await repo.createCentro(payload);
    } else {
      await repo.updateCentro(centro.id, payload);
    }
    ref.invalidate(centrosCustoListProvider);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Centro de custo salvo!')),
      );
    }
  }
}

class _CentroCard extends ConsumerWidget {
  const _CentroCard({required this.centro, required this.onChanged});

  final CentroCusto centro;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        title: Text(
          centro.nome,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color:
                centro.ativo ? AppColors.foreground : AppColors.mutedForeground,
          ),
        ),
        subtitle: centro.descricao != null && centro.descricao!.isNotEmpty
            ? Text(centro.descricao!)
            : null,
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.flag_outlined,
              size: 18, color: AppColors.primary),
        ),
        trailing: (ref.podeEditar('financeiro-centros-custo') ||
                ref.podeExcluir('financeiro-centros-custo'))
            ? PopupMenuButton<String>(
                onSelected: (v) => _acao(context, ref, v),
                itemBuilder: (_) => [
                  if (ref.podeEditar('financeiro-centros-custo'))
                    const PopupMenuItem(value: 'editar', child: Text('Editar')),
                  if (ref.podeEditar('financeiro-centros-custo'))
                    PopupMenuItem(
                      value: 'toggle',
                      child: Text(centro.ativo ? 'Desativar' : 'Ativar'),
                    ),
                  if (ref.podeExcluir('financeiro-centros-custo'))
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
        await _editar(context, ref);
      case 'toggle':
        await repo.updateCentro(centro.id, {'ativo': !centro.ativo});
        onChanged();
      case 'excluir':
        final uso = await repo.countUsoCentro(centro.id);
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
        final confirmar = await _confirmar(context, centro.nome);
        if (confirmar == true) {
          await repo.deleteCentro(centro.id);
          onChanged();
        }
    }
  }

  Future<void> _editar(BuildContext context, WidgetRef ref) async {
    final result = await showSimpleFormSheet(
      context,
      title: 'Editar Centro de Custo',
      fields: [
        SimpleField(key: 'nome', label: 'Nome *', initial: centro.nome, required: true),
        SimpleField(
          key: 'descricao',
          label: 'DescriÃ§Ã£o',
          initial: centro.descricao,
          maxLines: 3,
        ),
      ],
    );
    if (result == null) return;
    await ref.read(financeiroCadastrosRepositoryProvider).updateCentro(
      centro.id,
      {
        'nome': result['nome'],
        'descricao':
            (result['descricao'] ?? '').isEmpty ? null : result['descricao'],
      },
    );
    onChanged();
  }

  Future<bool?> _confirmar(BuildContext context, String nome) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir centro de custo'),
        content: Text('Excluir "$nome"?'),
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
  }
}
