import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../providers/user_management_providers.dart';
import '../../../providers/supabase_providers.dart';

/// Aba Usuários: lista, criação e alteração de perfil dos usuários.
class UsuariosTab extends ConsumerWidget {
  const UsuariosTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usuariosAsync = ref.watch(usuariosComRoleProvider);
    final perfis = ref.watch(perfisAcessoProvider).value ?? const [];

    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _novoUsuario(context, ref, perfis),
        icon: const Icon(Icons.person_add_alt),
        label: const Text('Novo Usuário'),
      ),
      body: usuariosAsync.when(
        loading: () => const LoadingView(),
        error: (e, _) => Center(child: Text('Erro: $e')),
        data: (usuarios) {
          if (usuarios.isEmpty) {
            return const Center(
              child: Text('Nenhum usuário encontrado.',
                  style: TextStyle(color: AppColors.mutedForeground)),
            );
          }
          return RefreshIndicator(
            onRefresh: () async =>
                ref.invalidate(usuariosComRoleProvider),
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
              itemCount: usuarios.length,
              itemBuilder: (context, i) {
                final u = usuarios[i];
                final nome = (u['nome'] as String?) ?? 'Usuário';
                final email = (u['email'] as String?) ?? '—';
                final role = u['role'] as String?;
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor:
                          AppColors.primary.withValues(alpha: 0.12),
                      child: Text(
                        nome.isNotEmpty ? nome[0].toUpperCase() : '?',
                        style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700),
                      ),
                    ),
                    title: Text(nome,
                        style:
                            const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(
                      '$email${role != null ? ' · $role' : ''}',
                      style: const TextStyle(fontSize: 12.5),
                    ),
                    trailing: PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert),
                      onSelected: (v) => _alterarRole(context, ref, u, v),
                      itemBuilder: (_) => perfis
                          .map((p) => PopupMenuItem(
                                value: p.slug,
                                child: Text('Perfil: ${p.nome}'),
                              ))
                          .toList(),
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

  Future<void> _alterarRole(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> usuario,
    String role,
  ) async {
    final userId = usuario['user_id'] as String?;
    if (userId == null) return;
    try {
      await ref.read(userManagementRepositoryProvider).updateUserRole(userId, role);
      ref.invalidate(usuariosComRoleProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Perfil atualizado')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erro: $e')));
      }
    }
  }

  Future<void> _novoUsuario(
    BuildContext context,
    WidgetRef ref,
    List<dynamic> perfis,
  ) async {
    final nome = TextEditingController();
    final email = TextEditingController();
    final senha = TextEditingController();
    String role = perfis.isNotEmpty ? perfis.first.slug as String : 'user';
    var salvando = false;

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Novo Usuário'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nome,
                  decoration: const InputDecoration(labelText: 'Nome'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'E-mail'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: senha,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Senha'),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: role,
                  decoration: const InputDecoration(labelText: 'Perfil'),
                  items: perfis
                      .map((p) => DropdownMenuItem<String>(
                            value: p.slug as String,
                            child: Text(p.nome as String),
                          ))
                      .toList(),
                  onChanged: (v) => setState(() => role = v ?? role),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: salvando
                  ? null
                  : () async {
                      if (nome.text.trim().isEmpty ||
                          email.text.trim().isEmpty ||
                          senha.text.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Preencha todos os campos')),
                        );
                        return;
                      }
                      setState(() => salvando = true);
                      try {
                        await ref
                            .read(userManagementRepositoryProvider)
                            .createUser(
                              email: email.text.trim(),
                              password: senha.text,
                              nome: nome.text.trim(),
                              role: role,
                            );
                        if (context.mounted) Navigator.pop(context, true);
                      } catch (e) {
                        if (context.mounted) {
                          setState(() => salvando = false);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Erro: $e')),
                          );
                        }
                      }
                    },
              child: Text(salvando ? 'Criando...' : 'Criar'),
            ),
          ],
        ),
      ),
    );
    nome.dispose();
    email.dispose();
    senha.dispose();
    if (ok == true) {
      ref.invalidate(usuariosComRoleProvider);
    }
  }
}
