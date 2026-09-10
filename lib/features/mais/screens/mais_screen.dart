import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_module.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../providers/auth_providers.dart';
import '../../../providers/supabase_providers.dart';

/// Aba "Mais": perfil do usuário e acesso a todos os módulos liberados para a
/// organização, respeitando as mesmas permissões de página do webapp.
class MaisScreen extends ConsumerWidget {
  const MaisScreen({super.key});

  static const _rotasBarra = {
    AppRoutes.dashboard,
    AppRoutes.obras,
    AppRoutes.producao,
    AppRoutes.estoque,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(appUserProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Mais')),
      body: userAsync.when(
        loading: () => const LoadingView(),
        error: (e, _) => Center(child: Text('Erro: $e')),
        data: (user) {
          if (user == null) return const LoadingView();
          final modulos = appModules
              .where((m) => !_rotasBarra.contains(m.route))
              .where((m) => user.podeAcessarPagina(m.pagina))
              .toList();

          final grupos = <String, List<AppModule>>{};
          for (final m in modulos) {
            grupos.putIfAbsent(m.group, () => []).add(m);
          }

          return ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              _CabecalhoUsuario(
                nome: user.displayName,
                email: user.email,
                organizacao: user.organizacao?.nome,
                role: user.role,
              ),
              if (modulos.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Nenhum módulo liberado para o seu perfil.',
                    style: TextStyle(color: AppColors.mutedForeground),
                  ),
                ),
              for (final entry in grupos.entries) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                  child: Text(
                    entry.key.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                      color: AppColors.mutedForeground,
                    ),
                  ),
                ),
                Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      for (var i = 0; i < entry.value.length; i++) ...[
                        _ModuloTile(modulo: entry.value[i]),
                        if (i < entry.value.length - 1)
                          const Divider(height: 1, indent: 56),
                      ],
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: OutlinedButton.icon(
                  onPressed: () => _confirmarSaida(context, ref),
                  icon: const Icon(Icons.logout, color: AppColors.destructive),
                  label: const Text(
                    'Sair da conta',
                    style: TextStyle(color: AppColors.destructive),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                      color: AppColors.destructive.withValues(alpha: 0.3),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _confirmarSaida(BuildContext context, WidgetRef ref) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sair da conta'),
        content: const Text('Deseja realmente encerrar a sessão?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.destructive,
            ),
            child: const Text('Sair'),
          ),
        ],
      ),
    );
    if (confirmar == true) {
      await ref.read(authServiceProvider).signOut();
    }
  }
}

class _CabecalhoUsuario extends StatelessWidget {
  const _CabecalhoUsuario({
    required this.nome,
    required this.email,
    required this.role,
    this.organizacao,
  });

  final String nome;
  final String email;
  final String role;
  final String? organizacao;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      color: AppColors.sidebar,
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: AppColors.primary,
            child: Text(
              nome.isNotEmpty ? nome[0].toUpperCase() : '?',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nome,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  email,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColors.sidebarForeground,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    if (organizacao != null)
                      _Tag(label: organizacao!, color: AppColors.accent),
                    _Tag(label: role, color: AppColors.info),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class _ModuloTile extends StatelessWidget {
  const _ModuloTile({required this.modulo});

  final AppModule modulo;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(modulo.icon, color: AppColors.primary),
      title: Text(modulo.label),
      trailing: const Icon(Icons.chevron_right,
          size: 20, color: AppColors.mutedForeground),
      onTap: () => context.push(modulo.route),
    );
  }
}
