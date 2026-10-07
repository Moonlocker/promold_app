import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../providers/superadmin_providers.dart';
import '../../../providers/supabase_providers.dart';

/// SuperAdmin — aba Feature Flags.
class SuperAdminFlagsTab extends ConsumerWidget {
  const SuperAdminFlagsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(featureFlagsAdminProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _form(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Nova flag'),
      ),
      body: async.when(
        loading: () => const LoadingView(),
        error: (e, _) => Center(child: Text('Erro: $e')),
        data: (flags) {
          if (flags.isEmpty) {
            return const EmptyState(
                icon: Icons.flag_outlined, title: 'Nenhuma feature flag');
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(featureFlagsAdminProvider),
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              itemCount: flags.length,
              itemBuilder: (context, i) {
                final f = flags[i];
                final enabled = (f['default_enabled'] as bool?) ?? false;
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    onTap: () => _overrides(context, ref, f),
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(f['nome'] as String? ?? 'Flag',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600)),
                        ),
                        if ((f['beta'] as bool?) == true)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.info.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: const Text('beta',
                                style: TextStyle(
                                    fontSize: 10, color: AppColors.info)),
                          ),
                      ],
                    ),
                    subtitle: Text(
                      '${f['slug'] ?? ''}'
                      '${(f['descricao'] as String?)?.isNotEmpty == true ? ' · ${f['descricao']}' : ''}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Switch(
                          value: enabled,
                          onChanged: (v) async {
                            await ref
                                .read(superAdminRepositoryProvider)
                                .saveFeatureFlag({'default_enabled': v},
                                    id: f['id'] as String);
                            ref.invalidate(featureFlagsAdminProvider);
                          },
                        ),
                        PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert),
                          onSelected: (v) async {
                            if (v == 'editar') {
                              await _form(context, ref, flag: f);
                            } else if (v == 'excluir') {
                              await ref
                                  .read(superAdminRepositoryProvider)
                                  .deleteFeatureFlag(f['id'] as String);
                              ref.invalidate(featureFlagsAdminProvider);
                            }
                          },
                          itemBuilder: (_) => const [
                            PopupMenuItem(
                                value: 'editar', child: Text('Editar')),
                            PopupMenuItem(
                                value: 'excluir',
                                child: Text('Excluir',
                                    style: TextStyle(
                                        color: AppColors.destructive))),
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
    Map<String, dynamic>? flag,
  }) async {
    final nome = TextEditingController(text: flag?['nome'] as String? ?? '');
    final slug = TextEditingController(text: flag?['slug'] as String? ?? '');
    final descricao =
        TextEditingController(text: flag?['descricao'] as String? ?? '');
    bool defaultEnabled = (flag?['default_enabled'] as bool?) ?? false;
    bool beta = (flag?['beta'] as bool?) ?? false;

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
                Text(flag == null ? 'Nova feature flag' : 'Editar feature flag',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 14),
                TextField(
                    controller: nome,
                    decoration: const InputDecoration(labelText: 'Nome *')),
                const SizedBox(height: 10),
                TextField(
                    controller: slug,
                    decoration: const InputDecoration(
                        labelText: 'Slug * (snake_case)')),
                const SizedBox(height: 10),
                TextField(
                    controller: descricao,
                    maxLines: 2,
                    decoration: const InputDecoration(labelText: 'Descrição')),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Habilitada por padrão'),
                  value: defaultEnabled,
                  onChanged: (v) => setSheet(() => defaultEnabled = v),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Beta'),
                  value: beta,
                  onChanged: (v) => setSheet(() => beta = v),
                ),
                const SizedBox(height: 10),
                FilledButton(
                  onPressed: () async {
                    if (slug.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Informe o slug')),
                      );
                      return;
                    }
                    await ref
                        .read(superAdminRepositoryProvider)
                        .saveFeatureFlag({
                      'nome': nome.text.trim(),
                      'slug': slug.text.trim(),
                      'descricao':
                          descricao.text.trim().isEmpty ? null : descricao.text.trim(),
                      'default_enabled': defaultEnabled,
                      'beta': beta,
                    }, id: flag?['id'] as String?);
                    ref.invalidate(featureFlagsAdminProvider);
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
    slug.dispose();
    descricao.dispose();
    if (ok == true && context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Flag salva')));
    }
  }

  Future<void> _overrides(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> flag,
  ) async {
    final flagId = flag['id'] as String;
    final orgs = ref.read(todasOrganizacoesProvider).value ?? const [];
    final overrides = await ref
        .read(superAdminRepositoryProvider)
        .listFeatureFlagOverrides(flagId);
    if (!context.mounted) return;
    final mapa = <String, bool>{
      for (final o in overrides)
        (o['organizacao_id'] as String): (o['enabled'] as bool?) ?? false,
    };

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
                Text('Overrides · ${flag['nome']}',
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                const Text(
                  'Padrão = usa a configuração global da flag.',
                  style: TextStyle(
                      fontSize: 11.5, color: AppColors.mutedForeground),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView(
                    children: [
                      for (final o in orgs)
                        _overrideRow(
                          context,
                          ref,
                          setSheet,
                          flagId: flagId,
                          orgId: o['id'] as String,
                          orgNome: o['nome'] as String? ?? '',
                          mapa: mapa,
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
    ref.invalidate(featureFlagOverridesProvider(flagId));
  }

  Widget _overrideRow(
    BuildContext context,
    WidgetRef ref,
    StateSetter setSheet, {
    required String flagId,
    required String orgId,
    required String orgNome,
    required Map<String, bool> mapa,
  }) {
    final atual = mapa.containsKey(orgId) ? (mapa[orgId]! ? 'on' : 'off') : 'default';
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      title: Text(orgNome, style: const TextStyle(fontSize: 13)),
      trailing: DropdownButton<String>(
        value: atual,
        underline: const SizedBox.shrink(),
        items: const [
          DropdownMenuItem(value: 'default', child: Text('Padrão')),
          DropdownMenuItem(value: 'on', child: Text('Ligado')),
          DropdownMenuItem(value: 'off', child: Text('Desligado')),
        ],
        onChanged: (v) async {
          bool? enabled;
          if (v == 'on') enabled = true;
          if (v == 'off') enabled = false;
          await ref.read(superAdminRepositoryProvider).setFeatureFlagOverride(
                organizacaoId: orgId,
                flagId: flagId,
                enabled: enabled,
              );
          if (enabled == null) {
            mapa.remove(orgId);
          } else {
            mapa[orgId] = enabled;
          }
          setSheet(() {});
        },
      ),
    );
  }
}
