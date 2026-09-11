import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/auth_providers.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/simple_form_sheet.dart';
import '../../../models/categoria_peca.dart';
import '../../../models/peca_catalogo.dart';
import '../../../providers/pecas_catalogo_providers.dart';
import '../../../providers/supabase_providers.dart';
import '../widgets/peca_form_sheet.dart';

/// CatÃ¡logo de PeÃ§as: peÃ§as e categorias.
class PecasScreen extends StatelessWidget {
  const PecasScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('CatÃ¡logo de PeÃ§as'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'PeÃ§as'),
              Tab(text: 'Categorias'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _PecasTab(),
            _CategoriasTab(),
          ],
        ),
      ),
    );
  }
}

class _PecasTab extends ConsumerStatefulWidget {
  const _PecasTab();

  @override
  ConsumerState<_PecasTab> createState() => _PecasTabState();
}

class _PecasTabState extends ConsumerState<_PecasTab> {
  String _busca = '';
  String _categoria = 'all';
  String _status = 'ativa';

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(pecasCatalogoListProvider);
    final categorias = ref.watch(categoriasPecaListProvider).value ?? const [];

    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: ref.podeCriar('pecas')
          ? FloatingActionButton.extended(
              onPressed: () async {
                final ok = await showPecaFormSheet(context);
                if (ok == true) ref.invalidate(pecasCatalogoListProvider);
              },
              icon: const Icon(Icons.add),
              label: const Text('Nova PeÃ§a'),
            )
          : null,
      body: async.when(
        loading: () => const LoadingView(),
        error: (e, _) => Center(child: Text('Erro: $e')),
        data: (pecas) {
          final filtradas = pecas.where((p) {
            if (!p.nome.toLowerCase().contains(_busca.toLowerCase())) {
              return false;
            }
            if (_categoria != 'all' && p.categoriaId != _categoria) return false;
            if (_status == 'ativa' && !p.ativa) return false;
            if (_status == 'inativa' && p.ativa) return false;
            return true;
          }).toList();

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(pecasCatalogoListProvider),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
              children: [
                TextField(
                  onChanged: (v) => setState(() => _busca = v),
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search, size: 20),
                    hintText: 'Buscar peÃ§a...',
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _categoria,
                        isDense: true,
                        decoration: const InputDecoration(
                            labelText: 'Categoria', isDense: true),
                        items: [
                          const DropdownMenuItem(
                              value: 'all', child: Text('Todas')),
                          ...categorias.map((c) => DropdownMenuItem(
                                value: c.id,
                                child: Text(c.nome,
                                    overflow: TextOverflow.ellipsis),
                              )),
                        ],
                        onChanged: (v) =>
                            setState(() => _categoria = v ?? 'all'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _status,
                        isDense: true,
                        decoration: const InputDecoration(
                            labelText: 'Status', isDense: true),
                        items: const [
                          DropdownMenuItem(value: 'ativa', child: Text('Ativas')),
                          DropdownMenuItem(
                              value: 'inativa', child: Text('Inativas')),
                          DropdownMenuItem(value: 'todas', child: Text('Todas')),
                        ],
                        onChanged: (v) =>
                            setState(() => _status = v ?? 'ativa'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (filtradas.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 48),
                    child: EmptyState(
                      icon: Icons.extension_outlined,
                      title: 'Nenhuma peÃ§a encontrada',
                    ),
                  )
                else
                  ...filtradas.map((p) => _PecaCard(
                        peca: p,
                        onChanged: () =>
                            ref.invalidate(pecasCatalogoListProvider),
                      )),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _PecaCard extends ConsumerWidget {
  const _PecaCard({required this.peca, required this.onChanged});

  final PecaCatalogo peca;
  final VoidCallback onChanged;

  String get _dimensoes {
    switch (peca.tipoCalculo) {
      case 'nao_linear':
        return '${peca.volumeConcretoPorMetro ?? '-'} mÂ³/m';
      case 'cilindrica':
        return 'Ã˜ ${peca.diametroPadrao ?? '-'} m';
      default:
        final partes = [
          peca.larguraPadrao,
          peca.alturaPadrao,
          if (peca.comprimentoPadrao != null) peca.comprimentoPadrao,
        ].where((e) => e != null).join(' Ã— ');
        return partes.isEmpty ? '-' : partes;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        onTap: ref.podeEditar('pecas')
            ? () async {
                final ok = await showPecaFormSheet(context, peca: peca);
                if (ok == true) onChanged();
              }
            : null,
        title: Row(
          children: [
            Flexible(
              child: Text(
                peca.nome,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: peca.ativa
                      ? AppColors.foreground
                      : AppColors.mutedForeground,
                ),
              ),
            ),
            const SizedBox(width: 8),
            if ((peca.identificadorPadrao ?? '').isNotEmpty)
              _Chip(
                label: peca.identificadorPadrao!,
                color: AppColors.info,
                mono: true,
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              [
                peca.categoria?.nome ?? '-',
                peca.tipoConcretoLabel,
                _dimensoes,
              ].join(' Â· '),
              style: const TextStyle(fontSize: 12.5),
            ),
          ],
        ),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.extension_outlined,
              size: 18, color: AppColors.primary),
        ),
        trailing: (ref.podeEditar('pecas') || ref.podeExcluir('pecas'))
            ? PopupMenuButton<String>(
          onSelected: (v) async {
            final repo = ref.read(pecasCatalogoRepositoryProvider);
            switch (v) {
              case 'toggle':
                await repo.toggleAtiva(peca.id, !peca.ativa);
                onChanged();
              case 'excluir':
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Excluir peÃ§a'),
                    content: Text('Excluir "${peca.nome}"?'),
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
                  try {
                    await repo.delete(peca.id);
                    onChanged();
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                              'NÃ£o foi possÃ­vel excluir: peÃ§a em uso em obras/composiÃ§Ãµes.'),
                        ),
                      );
                    }
                  }
                }
            }
          },
          itemBuilder: (_) => [
            if (ref.podeEditar('pecas'))
              PopupMenuItem(
                value: 'toggle',
                child: Text(peca.ativa ? 'Desativar' : 'Ativar'),
              ),
            if (ref.podeExcluir('pecas'))
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
}

class _CategoriasTab extends ConsumerStatefulWidget {
  const _CategoriasTab();

  @override
  ConsumerState<_CategoriasTab> createState() => _CategoriasTabState();
}

class _CategoriasTabState extends ConsumerState<_CategoriasTab> {
  String _busca = '';

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(categoriasPecaListProvider);
    final pecas = ref.watch(pecasCatalogoListProvider).value ?? const [];

    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: ref.podeCriar('pecas')
          ? FloatingActionButton.extended(
              onPressed: () => _abrirForm(context, ref),
              icon: const Icon(Icons.add),
              label: const Text('Nova Categoria'),
            )
          : null,
      body: async.when(
        loading: () => const LoadingView(),
        error: (e, _) => Center(child: Text('Erro: $e')),
        data: (categorias) {
          final filtradas = categorias
              .where((c) => c.nome.toLowerCase().contains(_busca.toLowerCase()))
              .toList();
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(categoriasPecaListProvider),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
              children: [
                TextField(
                  onChanged: (v) => setState(() => _busca = v),
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search, size: 20),
                    hintText: 'Buscar categoria...',
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 12),
                if (filtradas.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 48),
                    child: EmptyState(
                      icon: Icons.folder_open_outlined,
                      title: 'Nenhuma categoria',
                    ),
                  )
                else
                  ...filtradas.map((c) {
                    final count =
                        pecas.where((p) => p.categoriaId == c.id).length;
                    return _CategoriaPecaCard(
                      categoria: c,
                      count: count,
                      onChanged: () {
                        ref.invalidate(categoriasPecaListProvider);
                        ref.invalidate(pecasCatalogoListProvider);
                      },
                    );
                  }),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _abrirForm(BuildContext context, WidgetRef ref,
      {CategoriaPeca? categoria}) async {
    final result = await showSimpleFormSheet(
      context,
      title: categoria == null ? 'Nova Categoria' : 'Editar Categoria',
      submitLabel: categoria == null ? 'Cadastrar' : 'Salvar',
      fields: [
        SimpleField(
            key: 'nome',
            label: 'Nome *',
            initial: categoria?.nome,
            required: true),
        SimpleField(
            key: 'descricao',
            label: 'DescriÃ§Ã£o',
            initial: categoria?.descricao,
            maxLines: 3),
      ],
    );
    if (result == null) return;
    final repo = ref.read(pecasCatalogoRepositoryProvider);
    final payload = {
      'nome': result['nome'],
      'descricao':
          (result['descricao'] ?? '').isEmpty ? null : result['descricao'],
    };
    if (categoria == null) {
      await repo.createCategoria({...payload, 'ativa': true});
    } else {
      await repo.updateCategoria(categoria.id, payload);
    }
    ref.invalidate(categoriasPecaListProvider);
  }
}

class _CategoriaPecaCard extends ConsumerWidget {
  const _CategoriaPecaCard({
    required this.categoria,
    required this.count,
    required this.onChanged,
  });

  final CategoriaPeca categoria;
  final int count;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        title: Text(categoria.nome,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          categoria.descricao?.isNotEmpty == true
              ? '${categoria.descricao} Â· $count peÃ§as'
              : '$count peÃ§as',
        ),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.accent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.folder_open_outlined,
              size: 18, color: AppColors.accent),
        ),
        trailing: ref.podeExcluir('pecas')
            ? PopupMenuButton<String>(
          onSelected: (v) async {
            if (v == 'excluir') {
              if (count > 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Categoria possui peÃ§as vinculadas')),
                );
                return;
              }
              final ok = await showDialog<bool>(
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
              if (ok == true) {
                await ref
                    .read(pecasCatalogoRepositoryProvider)
                    .deleteCategoria(categoria.id);
                onChanged();
              }
            }
          },
          itemBuilder: (_) => const [
            PopupMenuItem(
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
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.color, this.mono = false});

  final String label;
  final Color color;
  final bool mono;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
          fontFamily: mono ? 'monospace' : null,
        ),
      ),
    );
  }
}
