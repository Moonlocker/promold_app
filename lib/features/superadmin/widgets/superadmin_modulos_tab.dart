import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../providers/superadmin_providers.dart';
import '../../../providers/supabase_providers.dart';

/// SuperAdmin — aba Módulos & Páginas.
class SuperAdminModulosTab extends ConsumerStatefulWidget {
  const SuperAdminModulosTab({super.key});

  @override
  ConsumerState<SuperAdminModulosTab> createState() =>
      _SuperAdminModulosTabState();
}

class _SuperAdminModulosTabState extends ConsumerState<SuperAdminModulosTab> {
  bool _modulos = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _modulos ? _formModulo(context) : _formPagina(context),
        icon: const Icon(Icons.add),
        label: Text(_modulos ? 'Novo módulo' : 'Nova página'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: SegmentedButton<bool>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: true, label: Text('Módulos')),
                ButtonSegment(value: false, label: Text('Páginas')),
              ],
              selected: {_modulos},
              onSelectionChanged: (s) => setState(() => _modulos = s.first),
            ),
          ),
          Expanded(child: _modulos ? const _ModulosList() : const _PaginasList()),
        ],
      ),
    );
  }

  Future<void> _formModulo(BuildContext context,
      {Map<String, dynamic>? modulo}) async {
    final nome = TextEditingController(text: modulo?['nome'] as String? ?? '');
    final slug = TextEditingController(text: modulo?['slug'] as String? ?? '');
    final descricao =
        TextEditingController(text: modulo?['descricao'] as String? ?? '');
    final categoria =
        TextEditingController(text: modulo?['categoria'] as String? ?? 'geral');
    final ordem = TextEditingController(
        text: ((modulo?['ordem'] as num?) ?? 0).toString());
    final valorMensal = TextEditingController(
        text: ((modulo?['valor_mensal'] as num?)?.toDouble() ?? 0)
            .toStringAsFixed(2));
    final precoM3 = TextEditingController(
        text: ((modulo?['preco_por_m3'] as num?)?.toDouble() ?? 0)
            .toStringAsFixed(2));
    bool ativo = (modulo?['ativo'] as bool?) ?? true;
    final ok = await _sheet(context, 'Módulo', [
      _field(nome, 'Nome *'),
      _field(slug, 'Slug *'),
      _field(descricao, 'Descrição'),
      _field(categoria, 'Categoria'),
      _field(ordem, 'Ordem', number: true),
      _field(valorMensal, 'Valor mensal (R\$)', number: true),
      _field(precoM3, 'Preço por m³ (R\$)', number: true),
      StatefulBuilder(
        builder: (context, setInner) => SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Ativo'),
          value: ativo,
          onChanged: (v) => setInner(() => ativo = v),
        ),
      ),
    ]);
    if (ok != true) {
      _dispose([nome, slug, descricao, categoria, ordem, valorMensal, precoM3]);
      return;
    }
    await ref.read(superAdminRepositoryProvider).saveModulo({
      'nome': nome.text.trim(),
      'slug': slug.text.trim(),
      'descricao': descricao.text.trim().isEmpty ? null : descricao.text.trim(),
      'categoria': categoria.text.trim(),
      'ordem': int.tryParse(ordem.text) ?? 0,
      'valor_mensal': double.tryParse(valorMensal.text.replaceAll(',', '.')),
      'preco_por_m3': double.tryParse(precoM3.text.replaceAll(',', '.')),
      'ativo': ativo,
    }, id: modulo?['id'] as String?);
    _dispose([nome, slug, descricao, categoria, ordem, valorMensal, precoM3]);
    ref.invalidate(modulosAdminProvider);
  }

  Future<void> _formPagina(BuildContext context,
      {Map<String, dynamic>? pagina}) async {
    final nome = TextEditingController(text: pagina?['nome'] as String? ?? '');
    final slug = TextEditingController(text: pagina?['slug'] as String? ?? '');
    final descricao =
        TextEditingController(text: pagina?['descricao'] as String? ?? '');
    final categoria =
        TextEditingController(text: pagina?['categoria'] as String? ?? '');
    final rota = TextEditingController(text: pagina?['rota'] as String? ?? '');
    final ordem = TextEditingController(
        text: ((pagina?['ordem'] as num?) ?? 0).toString());
    bool ativa = (pagina?['ativa'] as bool?) ?? true;
    bool defaultAtiva = (pagina?['default_ativa'] as bool?) ?? false;
    final ok = await _sheet(context, 'Página', [
      _field(nome, 'Nome *'),
      _field(slug, 'Slug *'),
      _field(descricao, 'Descrição'),
      _field(categoria, 'Categoria'),
      _field(rota, 'Rota'),
      _field(ordem, 'Ordem', number: true),
      StatefulBuilder(
        builder: (context, setInner) => Column(
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Padrão (todas orgs)'),
              value: defaultAtiva,
              onChanged: (v) => setInner(() => defaultAtiva = v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Ativa'),
              value: ativa,
              onChanged: (v) => setInner(() => ativa = v),
            ),
          ],
        ),
      ),
    ]);
    if (ok != true) {
      _dispose([nome, slug, descricao, categoria, rota, ordem]);
      return;
    }
    await ref.read(superAdminRepositoryProvider).savePagina({
      'nome': nome.text.trim(),
      'slug': slug.text.trim(),
      'descricao': descricao.text.trim().isEmpty ? null : descricao.text.trim(),
      'categoria': categoria.text.trim(),
      'rota': rota.text.trim().isEmpty ? null : rota.text.trim(),
      'ordem': int.tryParse(ordem.text) ?? 0,
      'default_ativa': defaultAtiva,
      'ativa': ativa,
    }, id: pagina?['id'] as String?);
    _dispose([nome, slug, descricao, categoria, rota, ordem]);
    ref.invalidate(paginasAdminProvider);
  }

  static void _dispose(List<TextEditingController> ctrls) {
    for (final c in ctrls) {
      c.dispose();
    }
  }

  static Widget _field(TextEditingController c, String label,
      {bool number = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: c,
        keyboardType:
            number ? const TextInputType.numberWithOptions(decimal: true) : null,
        decoration: InputDecoration(labelText: label, isDense: true),
      ),
    );
  }

  Future<bool?> _sheet(
    BuildContext context,
    String titulo,
    List<Widget> children,
  ) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(
            20, 16, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(titulo,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 14),
              ...children,
              const SizedBox(height: 8),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Salvar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModulosList extends ConsumerWidget {
  const _ModulosList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(modulosAdminProvider);
    return async.when(
      loading: () => const LoadingView(),
      error: (e, _) => Center(child: Text('Erro: $e')),
      data: (modulos) {
        if (modulos.isEmpty) {
          return const EmptyState(
              icon: Icons.widgets_outlined, title: 'Nenhum módulo');
        }
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(modulosAdminProvider),
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
            itemCount: modulos.length,
            itemBuilder: (context, i) {
              final m = modulos[i];
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  onTap: () => _vinculos(context, ref, m),
                  title: Text(m['nome'] as String? ?? 'Módulo',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(
                    '${m['slug'] ?? ''} · ${m['categoria'] ?? 'geral'}'
                    '${(m['valor_mensal'] as num?) != null ? ' · ${Formatters.moeda((m['valor_mensal'] as num).toDouble())}/mês' : ''}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert),
                    onSelected: (v) async {
                      if (v == 'editar') {
                        await _SuperAdminModulosTabState()._formModulo(context,
                            modulo: m);
                      } else if (v == 'excluir') {
                        await ref
                            .read(superAdminRepositoryProvider)
                            .deleteModulo(m['id'] as String);
                        ref.invalidate(modulosAdminProvider);
                        ref.invalidate(modulosPaginasAdminProvider);
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'editar', child: Text('Editar')),
                      PopupMenuItem(
                          value: 'excluir',
                          child: Text('Excluir',
                              style:
                                  TextStyle(color: AppColors.destructive))),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _vinculos(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> modulo,
  ) async {
    final paginas = ref.read(paginasAdminProvider).value ?? const [];
    final vinculos =
        ref.read(modulosPaginasAdminProvider).value ?? const [];
    final moduloId = modulo['id'] as String;
    final vinculadas = vinculos
        .where((v) => v['modulo_id'] == moduloId)
        .map((v) => v['pagina_slug'] as String)
        .toSet();
    final disponiveis = paginas.where((p) => true).toList();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheet) => Padding(
          padding: EdgeInsets.fromLTRB(
              20, 16, 20, 20 + MediaQuery.of(context).padding.bottom),
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.7,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Páginas de ${modulo['nome']}',
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView(
                    children: [
                      for (final p in disponiveis)
                        CheckboxListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          value: vinculadas.contains(p['slug']),
                          title: Text(p['nome'] as String? ?? ''),
                          subtitle: Text(p['slug'] as String? ?? '',
                              style: const TextStyle(fontSize: 11)),
                          onChanged: (v) async {
                            final slug = p['slug'] as String;
                            await ref
                                .read(superAdminRepositoryProvider)
                                .toggleVinculoModulo(
                                  moduloId: moduloId,
                                  paginaSlug: slug,
                                  vincular: v ?? false,
                                );
                            if (v == true) {
                              vinculadas.add(slug);
                            } else {
                              vinculadas.remove(slug);
                            }
                            setSheet(() {});
                            ref.invalidate(modulosPaginasAdminProvider);
                          },
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PaginasList extends ConsumerWidget {
  const _PaginasList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(paginasAdminProvider);
    return async.when(
      loading: () => const LoadingView(),
      error: (e, _) => Center(child: Text('Erro: $e')),
      data: (paginas) {
        if (paginas.isEmpty) {
          return const EmptyState(
              icon: Icons.description_outlined, title: 'Nenhuma página');
        }
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(paginasAdminProvider),
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
            itemCount: paginas.length,
            itemBuilder: (context, i) {
              final p = paginas[i];
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text(p['nome'] as String? ?? 'Página',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(
                    '${p['slug'] ?? ''} · ${p['categoria'] ?? ''}'
                    '${(p['default_ativa'] as bool?) == true ? ' · padrão' : ''}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert),
                    onSelected: (v) async {
                      if (v == 'editar') {
                        await _SuperAdminModulosTabState()
                            ._formPagina(context, pagina: p);
                      } else if (v == 'excluir') {
                        await ref
                            .read(superAdminRepositoryProvider)
                            .deletePagina(p['id'] as String);
                        ref.invalidate(paginasAdminProvider);
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'editar', child: Text('Editar')),
                      PopupMenuItem(
                          value: 'excluir',
                          child: Text('Excluir',
                              style:
                                  TextStyle(color: AppColors.destructive))),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
