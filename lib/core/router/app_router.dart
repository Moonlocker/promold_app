import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/splash_screen.dart';
import '../../features/dashboard/screens/dashboard_screen.dart';
import '../../features/estoque/screens/estoque_screen.dart';
import '../../features/leitores/leitor_configs.dart';
import '../../features/leitores/leitor_consulta_screen.dart';
import '../../features/leitores/leitor_estoque_screen.dart';
import '../../features/leitores/registrar_leitor_screen.dart';
import '../../features/mais/screens/mais_screen.dart';
import '../../features/obras/screens/obra_detalhe_screen.dart';
import '../../features/obras/screens/obras_screen.dart';
import '../../features/painel/screens/painel_fabrica_screen.dart';
import '../../features/planejamento/screens/planejamento_screen.dart';
import '../../features/producao/screens/producao_screen.dart';
import '../../features/shell/app_shell.dart';
import '../../providers/auth_providers.dart';
import '../widgets/module_placeholder.dart';
import 'app_module.dart';
import 'app_routes.dart';

/// Rotas que possuem tela própria (as demais viram placeholder).
const Set<String> _rotasImplementadas = {
  AppRoutes.dashboard,
  AppRoutes.obras,
  AppRoutes.producao,
  AppRoutes.painel,
  AppRoutes.planejamento,
  AppRoutes.estoque,
  AppRoutes.leitorConsulta,
  AppRoutes.leitorArmada,
  AppRoutes.leitorConcretada,
  AppRoutes.leitorEstoque,
  AppRoutes.leitorMontagem,
};

/// Notifica o GoRouter sempre que a sessão muda.
class _RouterRefresh extends ChangeNotifier {
  _RouterRefresh(Ref ref) {
    ref.listen(sessionProvider, (_, _) => notifyListeners());
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _RouterRefresh(ref);
  ref.onDispose(refresh.dispose);

  final placeholderRoutes = appModules
      .where((m) => !_rotasImplementadas.contains(m.route))
      .map(
        (m) => GoRoute(
          path: m.route,
          builder: (context, state) =>
              ModulePlaceholderScreen(title: m.label, icon: m.icon),
        ),
      );

  return GoRouter(
    initialLocation: '/',
    refreshListenable: refresh,
    redirect: (context, state) {
      final session = ref.read(sessionProvider);
      final location = state.matchedLocation;
      final isLogin = location == AppRoutes.login;
      final isSplash = location == '/';

      if (session.isLoading) return null;

      final loggedIn = session.value != null;

      if (!loggedIn) {
        return isLogin ? null : AppRoutes.login;
      }
      if (isLogin || isSplash) return AppRoutes.dashboard;
      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (_, _) => const SplashScreen()),
      GoRoute(path: AppRoutes.login, builder: (_, _) => const LoginScreen()),
      GoRoute(
        path: '/obras/:id',
        builder: (context, state) =>
            ObraDetalheScreen(obraId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: AppRoutes.painel,
        builder: (_, _) => const PainelFabricaScreen(),
      ),
      GoRoute(
        path: AppRoutes.planejamento,
        builder: (_, _) => const PlanejamentoScreen(),
      ),
      GoRoute(
        path: AppRoutes.leitorConsulta,
        builder: (_, _) => const LeitorConsultaScreen(),
      ),
      GoRoute(
        path: AppRoutes.leitorArmada,
        builder: (_, _) =>
            const RegistrarLeitorScreen(config: leitorArmadaConfig),
      ),
      GoRoute(
        path: AppRoutes.leitorConcretada,
        builder: (_, _) =>
            const RegistrarLeitorScreen(config: leitorConcretadaConfig),
      ),
      GoRoute(
        path: AppRoutes.leitorMontagem,
        builder: (_, _) =>
            const RegistrarLeitorScreen(config: leitorMontagemConfig),
      ),
      GoRoute(
        path: AppRoutes.leitorEstoque,
        builder: (_, _) => const LeitorEstoqueScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.dashboard,
                builder: (_, _) => const DashboardScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.obras,
                builder: (_, _) => const ObrasScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.producao,
                builder: (_, _) => const ProducaoScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.estoque,
                builder: (_, _) => const EstoqueScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.mais,
                builder: (_, _) => const MaisScreen(),
              ),
            ],
          ),
        ],
      ),
      ...placeholderRoutes,
    ],
  );
});
