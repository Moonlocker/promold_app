import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/offline_banner.dart';
import '../../../providers/auth_providers.dart';
import '../leitores/widgets/global_qr_scanner_sheet.dart';

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
    final podeConsultar = user?.podeAcessarPagina('leitor-consulta') ?? true;

    return Scaffold(
      body: Column(
        children: [
          const OfflineBanner(),
          Expanded(child: navigationShell),
        ],
      ),
      floatingActionButton: !podeConsultar
          ? null
          : FloatingActionButton.small(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              tooltip: 'Ler QR Code da peça',
              onPressed: () => _escanear(context),
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

  Future<void> _escanear(BuildContext context) async {
    final code = await showGlobalQrScanner(context);
    if (code == null || code.trim().isEmpty || !context.mounted) return;
    context.push('/leitor-consulta?code=${Uri.encodeComponent(code.trim())}');
  }
}
