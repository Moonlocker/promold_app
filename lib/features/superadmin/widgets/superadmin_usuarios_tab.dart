import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../providers/superadmin_providers.dart';
import '../../../providers/supabase_providers.dart';

const _roles = ['admin', 'gerente', 'operador', 'visualizador', 'superadmin'];

/// SuperAdmin — aba Usuários (profiles + user_roles).
class SuperAdminUsuariosTab extends ConsumerStatefulWidget {
  const SuperAdminUsuariosTab({super.key});

  @override
  ConsumerState<SuperAdminUsuariosTab> createState() =>
      _SuperAdminUsuariosTabState();
}

class _SuperAdminUsuariosTabState
    extends ConsumerState<SuperAdminUsuariosTab> {
  String _busca = '';

  @override
  Widget build(BuildContext context) {
    final profilesAsync = ref.watch(profilesAdminProvider);
    final rolesAsync = ref.watch(userRolesAdminProvider);
    final orgs = ref.watch(todasOrganizacoesProvider).value ?? const [];

    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _novo(orgs),
        icon: const Icon(Icons.person_add_alt_1_outlined),
        label: const Text('Novo usuário'),
      ),
      body: profilesAsync.when(
        loading: () => const LoadingView(),
        error: (e, _) => Center(child: Text('Erro: $e')),
        data: (profiles) {
          final roles = rolesAsync.value ?? const [];
          final rolePorUser = <String, String>{
            for (final r in roles)
              (r['user_id'] as String? ?? ''): (r['role'] as String? ?? ''),
          };
          final orgNome = <String, String>{
            for (final o in orgs) (o['id'] as String): (o['nome'] as String? ?? ''),
          };
          final t = _busca.toLowerCase();
          final filtrados = profiles.where((p) {
            if (t.isEmpty) return true;
            return [
              p['nome'],
              p['email'],
              orgNome[p['organizacao_id']],
            ].whereType<String>().any((x) => x.toLowerCase().contains(t));
          }).toList();

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: TextField(
                  onChanged: (v) => setState(() => _busca = v),
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search, size: 20),
                    hintText: 'Buscar por nome, e-mail ou organização...',
                    isDense: true,
                  ),
                ),
              ),
              Expanded(
                child: filtrados.isEmpty
                    ? const EmptyState(
                        icon: Icons.people_outline,
                        title: 'Nenhum usuário',
                      )
                    : RefreshIndicator(
                        onRefresh: () async {
                          ref.invalidate(profilesAdminProvider);
                          ref.invalidate(userRolesAdminProvider);
                        },
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                          itemCount: filtrados.length,
                          itemBuilder: (context, i) {
                            final p = filtrados[i];
                            final userId = p['user_id'] as String? ?? '';
                            return Card(
                              margin: const EdgeInsets.only(bottom: 10),
                              child: ListTile(
                                title: Text(
                                  (p['nome'] as String?) ??
                                      (p['email'] as String?) ??
                                      'Usuário',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600),
                                ),
                                subtitle: Text(
                                  '${p['email'] ?? '—'} · '
                                  '${orgNome[p['organizacao_id']] ?? 'Sem org'} · '
                                  '${rolePorUser[userId] ?? 'sem papel'}',
                                  style: const TextStyle(fontSize: 12),
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if ((p['ativo'] as bool?) == false)
                                      const Padding(
                                        padding: EdgeInsets.only(right: 8),
                                        child: Text('Inativo',
                                            style: TextStyle(
                                                color:
                                                    AppColors.mutedForeground,
                                                fontSize: 11)),
                                      ),
                                    PopupMenuButton<String>(
                                      icon: const Icon(Icons.more_vert),
                                      onSelected: (v) => _acao(
                                          context, ref, p, userId, v, orgs),
                                      itemBuilder: (_) => [
                                        const PopupMenuItem(
                                            value: 'editar',
                                            child: Text('Editar')),
                                        PopupMenuItem(
                                          value: 'toggle',
                                          child: Text(
                                              (p['ativo'] as bool?) == false
                                                  ? 'Ativar'
                                                  : 'Desativar'),
                                        ),
                                        const PopupMenuItem(
                                            value: 'impersonate',
                                            child: Text('Entrar como')),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _acao(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> profile,
    String userId,
    String acao,
    List<Map<String, dynamic>> orgs,
  ) async {
    final repo = ref.read(superAdminRepositoryProvider);
    switch (acao) {
      case 'editar':
        await _editar(ref, profile, userId, orgs);
      case 'toggle':
        final ativo = (profile['ativo'] as bool?) ?? true;
        await repo.updateProfile(userId, {'ativo': !ativo});
        await repo.registrarAudit(
          acao: 'editar_usuario',
          alvoTipo: 'user',
          alvoId: userId,
          alvoDescricao: profile['nome'] as String?,
        );
        ref.invalidate(profilesAdminProvider);
      case 'impersonate':
        try {
          await repo.impersonateUser(userId);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('Impersonação iniciada no web.')),
            );
          }
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text('Erro: $e')));
          }
        }
    }
  }

  Future<void> _novo(List<Map<String, dynamic>> orgs) async {
    final nome = TextEditingController();
    final email = TextEditingController();
    final senha = TextEditingController();
    String? orgId;
    String role = 'operador';

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
                const Text('Novo usuário',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 14),
                TextField(
                    controller: nome,
                    decoration: const InputDecoration(labelText: 'Nome *')),
                const SizedBox(height: 10),
                TextField(
                    controller: email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(labelText: 'E-mail *')),
                const SizedBox(height: 10),
                TextField(
                    controller: senha,
                    obscureText: true,
                    decoration: const InputDecoration(
                        labelText: 'Senha * (mín. 6)')),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: orgId,
                  isExpanded: true,
                  decoration:
                      const InputDecoration(labelText: 'Organização *'),
                  items: orgs
                      .map((o) => DropdownMenuItem(
                            value: o['id'] as String,
                            child: Text(o['nome'] as String? ?? '',
                                overflow: TextOverflow.ellipsis),
                          ))
                      .toList(),
                  onChanged: (v) => setSheet(() => orgId = v),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: role,
                  decoration: const InputDecoration(labelText: 'Perfil *'),
                  items: _roles
                      .map((r) =>
                          DropdownMenuItem(value: r, child: Text(r)))
                      .toList(),
                  onChanged: (v) => setSheet(() => role = v ?? 'operador'),
                ),
                const SizedBox(height: 18),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Criar'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (ok != true) {
      nome.dispose();
      email.dispose();
      senha.dispose();
      return;
    }
    if (nome.text.trim().isEmpty ||
        email.text.trim().isEmpty ||
        senha.text.length < 6 ||
        orgId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Preencha nome, e-mail, senha (6+) e organização')),
        );
      }
      nome.dispose();
      email.dispose();
      senha.dispose();
      return;
    }
    try {
      await ref.read(superAdminRepositoryProvider).createUser({
        'email': email.text.trim(),
        'password': senha.text,
        'nome': nome.text.trim(),
        'role': role,
        'organizacao_id': orgId,
      });
      ref.invalidate(profilesAdminProvider);
      ref.invalidate(userRolesAdminProvider);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Usuário criado')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erro: $e')));
      }
    } finally {
      nome.dispose();
      email.dispose();
      senha.dispose();
    }
  }

  Future<void> _editar(
    WidgetRef ref,
    Map<String, dynamic> profile,
    String userId,
    List<Map<String, dynamic>> orgs,
  ) async {
    final roles = ref.read(userRolesAdminProvider).value ?? const [];
    final roleAtual = roles
        .where((r) => r['user_id'] == userId)
        .map((r) => r['role'] as String?)
        .firstOrNull;
    final nome = TextEditingController(text: profile['nome'] as String? ?? '');
    String? orgId = profile['organizacao_id'] as String?;
    String role = roleAtual ?? 'visualizador';
    bool ativo = (profile['ativo'] as bool?) ?? true;

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
                const Text('Editar usuário',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 14),
                TextField(
                    controller: nome,
                    decoration: const InputDecoration(labelText: 'Nome')),
                const SizedBox(height: 10),
                DropdownButtonFormField<String?>(
                  initialValue: orgId,
                  isExpanded: true,
                  decoration:
                      const InputDecoration(labelText: 'Organização'),
                  items: [
                    const DropdownMenuItem<String?>(
                        value: null, child: Text('Sem organização')),
                    ...orgs.map((o) => DropdownMenuItem<String?>(
                          value: o['id'] as String,
                          child: Text(o['nome'] as String? ?? '',
                              overflow: TextOverflow.ellipsis),
                        )),
                  ],
                  onChanged: (v) => setSheet(() => orgId = v),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: role,
                  decoration: const InputDecoration(labelText: 'Perfil'),
                  items: _roles
                      .map((r) =>
                          DropdownMenuItem(value: r, child: Text(r)))
                      .toList(),
                  onChanged: (v) => setSheet(() => role = v ?? role),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Ativo'),
                  value: ativo,
                  onChanged: (v) => setSheet(() => ativo = v),
                ),
                const SizedBox(height: 10),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Salvar'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (ok != true) {
      nome.dispose();
      return;
    }
    try {
      final repo = ref.read(superAdminRepositoryProvider);
      await repo.updateProfile(userId, {
        'nome': nome.text.trim(),
        'ativo': ativo,
        'organizacao_id': orgId,
      });
      await repo.upsertUserRole(userId, role);
      await repo.registrarAudit(
        acao: 'editar_usuario',
        alvoTipo: 'user',
        alvoId: userId,
        alvoDescricao: nome.text.trim(),
      );
      ref.invalidate(profilesAdminProvider);
      ref.invalidate(userRolesAdminProvider);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Usuário atualizado')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erro: $e')));
      }
    } finally {
      nome.dispose();
    }
  }
}
