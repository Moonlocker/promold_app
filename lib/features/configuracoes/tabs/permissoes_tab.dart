import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../models/permissoes.dart';
import '../../../providers/user_management_providers.dart';
import '../../../providers/supabase_providers.dart';

/// Aba Permissões: configura Ver/Criar/Editar/Excluir por perfil e página.
class PermissoesTab extends ConsumerStatefulWidget {
  const PermissoesTab({super.key});

  @override
  ConsumerState<PermissoesTab> createState() => _PermissoesTabState();
}

class _PermissoesTabState extends ConsumerState<PermissoesTab> {
  String? _role;
  List<Permissao> _local = [];

  @override
  Widget build(BuildContext context) {
    final perfisAsync = ref.watch(perfisAcessoProvider);
    final permissoesAsync = ref.watch(permissoesProvider);

    if (perfisAsync.isLoading || permissoesAsync.isLoading) {
      return const LoadingView();
    }
    final perfis = perfisAsync.value ?? const <PerfilAcesso>[];
    final todas = permissoesAsync.value ?? const <Permissao>[];

    if (_role == null && perfis.isNotEmpty) {
      _role = perfis.firstWhere((p) => p.slug != 'admin',
          orElse: () => perfis.first).slug;
    }
    // Sincroniza cópia local quando o provider muda.
    if (_local.length != todas.length ||
        (_local.isNotEmpty &&
            todas.isNotEmpty &&
            _local.first.id != todas.first.id)) {
      _local = List.of(todas);
    }

    final isAdmin = _role == 'admin';
    final doRole = _local.where((p) => p.role == _role).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _role,
                  isExpanded: true,
                  decoration: const InputDecoration(
                      labelText: 'Perfil', isDense: true),
                  items: perfis
                      .map((p) => DropdownMenuItem(
                            value: p.slug,
                            child: Text(
                                '${p.nome}${p.isSistema ? ' (Sistema)' : ''}'),
                          ))
                      .toList(),
                  onChanged: (v) => setState(() => _role = v),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                tooltip: 'Novo perfil',
                onPressed: () => _novoPerfil(context),
                icon: const Icon(Icons.add),
              ),
              if (_role != null && !isAdmin)
                IconButton(
                  tooltip: 'Excluir perfil',
                  onPressed: () => _excluirPerfil(perfis),
                  icon: const Icon(Icons.delete_outline,
                      color: AppColors.destructive),
                ),
            ],
          ),
        ),
        if (isAdmin)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Administradores têm acesso total a todas as funcionalidades.',
              style: TextStyle(color: AppColors.mutedForeground),
            ),
          )
        else
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              itemCount: allPages.length,
              itemBuilder: (context, i) {
                final pagina = allPages[i];
                final perm = doRole.where((p) => p.pagina == pagina).firstOrNull;
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(paginaLabel(pagina),
                            style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w600)),
                        if (perm == null)
                          const Padding(
                            padding: EdgeInsets.only(top: 4),
                            child: Text('sem permissão configurada',
                                style: TextStyle(
                                    fontSize: 11,
                                    fontStyle: FontStyle.italic,
                                    color: AppColors.mutedForeground)),
                          )
                        else
                          Wrap(
                            spacing: 4,
                            children: [
                              _PermSwitch(
                                label: 'Ver',
                                value: perm.podeVisualizar,
                                onChanged: (v) =>
                                    _toggle(perm, 'pode_visualizar', v),
                              ),
                              _PermSwitch(
                                label: 'Criar',
                                value: perm.podeCriar,
                                onChanged: (v) =>
                                    _toggle(perm, 'pode_criar', v),
                              ),
                              _PermSwitch(
                                label: 'Editar',
                                value: perm.podeEditar,
                                onChanged: (v) =>
                                    _toggle(perm, 'pode_editar', v),
                              ),
                              _PermSwitch(
                                label: 'Excluir',
                                value: perm.podeExcluir,
                                onChanged: (v) =>
                                    _toggle(perm, 'pode_excluir', v),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Future<void> _toggle(Permissao perm, String campo, bool value) async {
    setState(() {
      _local = _local
          .map((p) => p.id == perm.id ? _aplicar(p, campo, value) : p)
          .toList();
    });
    try {
      await ref
          .read(userManagementRepositoryProvider)
          .updatePermissao(perm.id, campo, value);
    } catch (e) {
      // Reverte em caso de erro.
      setState(() {
        _local = _local
            .map((p) => p.id == perm.id ? _aplicar(p, campo, !value) : p)
            .toList();
      });
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erro: $e')));
      }
    }
  }

  Permissao _aplicar(Permissao p, String campo, bool value) {
    return switch (campo) {
      'pode_visualizar' => p.copyWith(podeVisualizar: value),
      'pode_criar' => p.copyWith(podeCriar: value),
      'pode_editar' => p.copyWith(podeEditar: value),
      _ => p.copyWith(podeExcluir: value),
    };
  }

  Future<void> _novoPerfil(BuildContext context) async {
    final nome = TextEditingController();
    final descricao = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Novo Perfil de Acesso'),
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
            child: const Text('Criar'),
          ),
        ],
      ),
    );
    if (ok != true || nome.text.trim().isEmpty) {
      nome.dispose();
      descricao.dispose();
      return;
    }
    final slug = _slugify(nome.text.trim());
    try {
      await ref.read(userManagementRepositoryProvider).createPerfil(
            nome: nome.text.trim(),
            slug: slug,
            descricao:
                descricao.text.trim().isEmpty ? null : descricao.text.trim(),
          );
      ref.invalidate(perfisAcessoProvider);
      ref.invalidate(permissoesProvider);
      setState(() => _role = slug);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erro: $e')));
      }
    }
    nome.dispose();
    descricao.dispose();
  }

  Future<void> _excluirPerfil(List<PerfilAcesso> perfis) async {
    final perfil = perfis.where((p) => p.slug == _role).firstOrNull;
    if (perfil == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir perfil'),
        content: Text('Excluir "${perfil.nome}" e suas permissões?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.destructive),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(userManagementRepositoryProvider).deletePerfil(perfil);
    ref.invalidate(perfisAcessoProvider);
    ref.invalidate(permissoesProvider);
    setState(() => _role = null);
  }

  static String _slugify(String text) {
    const acentos = {
      'á': 'a', 'à': 'a', 'ã': 'a', 'â': 'a', 'ä': 'a',
      'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
      'í': 'i', 'ì': 'i', 'î': 'i', 'ï': 'i',
      'ó': 'o', 'ò': 'o', 'õ': 'o', 'ô': 'o', 'ö': 'o',
      'ú': 'u', 'ù': 'u', 'û': 'u', 'ü': 'u',
      'ç': 'c', 'ñ': 'n',
    };
    final lower = text.toLowerCase();
    final buffer = StringBuffer();
    for (final ch in lower.split('')) {
      buffer.write(acentos[ch] ?? ch);
    }
    return buffer
        .toString()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
  }
}

class _PermSwitch extends StatelessWidget {
  const _PermSwitch({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 84,
      child: Column(
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 10.5, color: AppColors.mutedForeground)),
          Switch(
            value: value,
            onChanged: onChanged,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ],
      ),
    );
  }
}
