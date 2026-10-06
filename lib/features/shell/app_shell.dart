import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/offline_banner.dart';
import '../../../providers/auth_providers.dart';
import '../leitores/leitor_atalhos.dart';
import '../leitores/leitores_hub_screen.dart';

/// Casca autenticada do aplicativo: mantém a barra de navegação inferior e o
/// estado de cada aba.
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  static const _destinations = <NavigationDestination>[
    NavigationDestination(
      icon: Icon(Icons.dashboard_outlined),
      selectedIcon: Icon(Icons.dashboard),
      label: 'Início',
    ),
    NavigationDestination(
      icon: Icon(Icons.business_outlined),
      selectedIcon: Icon(Icons.business),
      label: 'Obras',
    ),
    NavigationDestination(
      icon: Icon(Icons.bar_chart_outlined),
      selectedIcon: Icon(Icons.bar_chart),
      label: 'Produção',
    ),
    NavigationDestination(
      icon: Icon(Icons.qr_code_scanner),
      selectedIcon: Icon(Icons.qr_code_scanner),
      label: 'Leitores',
    ),
    NavigationDestination(
      icon: Icon(Icons.menu),
      selectedIcon: Icon(Icons.menu_open),
      label: 'Mais',
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Mantém o provider de usuário ativo enquanto o app está autenticado.
    final user = ref.watch(appUserProvider).value;

    final atalhos = leitorAtalhos
        .where((l) => user?.podeAcessarPagina(l.pagina) ?? true)
        .toList();

    return Scaffold(
      body: Column(
        children: [
          const OfflineBanner(),
          Expanded(child: navigationShell),
        ],
      ),
      floatingActionButton: atalhos.isEmpty
          ? null
          : FloatingActionButton.small(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              tooltip: 'Leitores QR',
              onPressed: () => _abrirLeitores(context, atalhos),
              child: const Icon(Icons.qr_code_scanner),
            ),
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: NavigationBar(
          selectedIndex: navigationShell.currentIndex,
          onDestinationSelected: (index) => navigationShell.goBranch(
            index,
            initialLocation: index == navigationShell.currentIndex,
          ),
          destinations: _destinations,
        ),
      ),
    );
  }

  void _abrirLeitores(BuildContext context, List<LeitorAtalho> atalhos) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.qr_code_scanner, color: AppColors.primary),
                  const SizedBox(width: 8),
                  const Text('Leitores QR',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700)),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(sheetContext),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              for (final l in atalhos) ...[
                LeitorCard(
                  item: l,
                  onTap: () {
                    Navigator.pop(sheetContext);
                    context.push(l.rota);
                  },
                ),
                const SizedBox(height: 8),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
