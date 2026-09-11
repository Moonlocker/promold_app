import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/screens/conta_bloqueada_screen.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/splash_screen.dart';
import '../../features/clientes/screens/clientes_screen.dart';
import '../../features/configuracoes/screens/configuracoes_screen.dart';
import '../../features/dashboard/screens/dashboard_screen.dart';
import '../../features/equipe/screens/equipe_screen.dart';
import '../../features/estoque/screens/estoque_screen.dart';
import '../../features/financeiro/screens/categorias_financeiras_screen.dart';
import '../../features/financeiro/screens/centros_custo_screen.dart';
import '../../features/financeiro/screens/conciliacao_bancaria_screen.dart';
import '../../features/financeiro/screens/contas_screen.dart';
import '../../features/financeiro/screens/dashboard_financeiro_screen.dart';
import '../../features/financeiro/screens/integracoes_financeiras_screen.dart';
import '../../features/fiscal/screens/emitir_nota_screen.dart';
import '../../features/fiscal/screens/fiscal_configuracao_screen.dart';
import '../../features/fiscal/screens/notas_emitidas_screen.dart';
import '../../features/fiscal/screens/notas_recebidas_screen.dart';
import '../../features/fornecedores/screens/fornecedores_screen.dart';
import '../../features/frota/screens/frota_screen.dart';
import '../../features/leitores/leitor_configs.dart';
import '../../features/leitores/leitor_consulta_screen.dart';
import '../../features/leitores/leitor_estoque_screen.dart';
import '../../features/leitores/registrar_leitor_screen.dart';
import '../../features/mais/screens/mais_screen.dart';
import '../../features/minha_fatura/screens/minha_fatura_screen.dart';
import '../../features/obras/screens/obra_detalhe_screen.dart';
import '../../features/obras/screens/obras_screen.dart';
import '../../features/onboarding/screens/onboarding_screen.dart';
import '../../features/orcamentos/screens/orcamentos_screen.dart';
import '../../features/painel/screens/painel_fabrica_screen.dart';
import '../../features/pecas/screens/pecas_screen.dart';
import '../../features/planejamento/screens/planejamento_screen.dart';
import '../../features/producao/screens/producao_screen.dart';
import '../../features/qualidade/screens/qualidade_dashboard_screen.dart';
import '../../features/qualidade/screens/qualidade_ensaios_screen.dart';
import '../../features/qualidade/screens/qualidade_rastreabilidade_screen.dart';
import '../../features/shell/app_shell.dart';
import '../../features/superadmin/screens/superadmin_screen.dart';
import '../../features/suporte/screens/suporte_screen.dart';
import '../../features/visao_geral/screens/visao_geral_screen.dart';
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
  AppRoutes.pecas,
  AppRoutes.clientes,
  AppRoutes.fornecedores,
  AppRoutes.equipe,
  AppRoutes.financeiroCentrosCusto,
  AppRoutes.financeiroCategorias,
  AppRoutes.financeiroDashboard,
  AppRoutes.financeiroContasPagar,
  AppRoutes.financeiroContasReceber,
  AppRoutes.financeiroConciliacao,
  AppRoutes.financeiroIntegracoes,
  AppRoutes.qualidadeDashboard,
  AppRoutes.qualidadeEnsaios,
  AppRoutes.qualidadeRastreabilidade,
  AppRoutes.fiscalEmitir,
  AppRoutes.fiscalNotas,
  AppRoutes.fiscalRecebidas,
  AppRoutes.fiscalConfiguracao,
  AppRoutes.frota,
  AppRoutes.suporte,
  AppRoutes.configuracoes,
  AppRoutes.minhaFatura,
  AppRoutes.visaoGeral,
  AppRoutes.orcamentos,
};

/// Notifica o GoRouter sempre que a sessão ou o usuário mudam.
class _RouterRefresh extends ChangeNotifier {
  _RouterRefresh(Ref ref) {
    ref.listen(sessionProvider, (_, _) => notifyListeners());
    ref.listen(appUserProvider, (_, _) => notifyListeners());
  }
}

/// Mapeia a rota atual para o slug de página usado nas permissões.
String? _paginaFromLocation(String location) {
  if (location.startsWith('/dashboard')) return 'dashboard';
  if (location.startsWith('/obras')) return 'obras';
  if (location.startsWith('/producao')) return 'indicadores';
  if (location.startsWith('/painel')) return 'painel-fabrica';
  if (location.startsWith('/planejamento')) return 'planejamento';
  if (location.startsWith('/pecas')) return 'pecas';
  if (location.startsWith('/visao-geral')) return 'visao-geral';
  if (location.startsWith('/estoque')) return 'estoque';
  if (location.startsWith('/orcamentos')) return 'orcamentos';
  if (location.startsWith('/frota')) return 'frota';
  if (location.startsWith('/fornecedores')) return 'fornecedores';
  if (location.startsWith('/equipe')) return 'equipe';
  if (location.startsWith('/clientes')) return 'clientes';
  if (location.startsWith('/configuracoes')) return 'configuracoes';
  if (location.startsWith('/leitor-consulta')) return 'leitor-consulta';
  if (location.startsWith('/leitor-armada')) return 'leitor-armada';
  if (location.startsWith('/leitor-concretada')) return 'leitor-concretada';
  if (location.startsWith('/leitor-estoque')) return 'leitor-estoque';
  if (location.startsWith('/leitor-montagem')) return 'leitor-montagem';
  if (location.startsWith('/qualidade/dashboard')) return 'qualidade-dashboard';
  if (location.startsWith('/qualidade/ensaios')) return 'qualidade-ensaios';
  if (location.startsWith('/qualidade/rastreabilidade')) {
    return 'qualidade-rastreabilidade';
  }
  if (location.startsWith('/financeiro/dashboard')) return 'financeiro-dashboard';
  if (location.startsWith('/financeiro/contas-pagar')) {
    return 'financeiro-contas-pagar';
  }
  if (location.startsWith('/financeiro/contas-receber')) {
    return 'financeiro-contas-receber';
  }
  if (location.startsWith('/financeiro/conciliacao')) {
    return 'financeiro-conciliacao';
  }
  if (location.startsWith('/financeiro/categorias')) return 'financeiro-categorias';
  if (location.startsWith('/financeiro/centros-custo')) {
    return 'financeiro-centros-custo';
  }
  if (location.startsWith('/financeiro/integracoes')) {
    return 'financeiro-integracoes';
  }
  if (location.startsWith('/fiscal/emitir')) return 'fiscal-emitir';
  if (location.startsWith('/fiscal/notas')) return 'fiscal-notas';
  if (location.startsWith('/fiscal/recebidas')) return 'fiscal-recebidas';
  if (location.startsWith('/fiscal/configuracao')) return 'fiscal-configuracao';
  return null;
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
      final isOnboarding = location == AppRoutes.onboarding;
      final isSplash = location == '/';
      final isBlocked = location == AppRoutes.contaBloqueada;

      if (session.isLoading) return null;

      final loggedIn = session.value != null;

      if (!loggedIn) {
        return (isLogin || isOnboarding) ? null : AppRoutes.login;
      }
      if (isLogin || isSplash) return AppRoutes.dashboard;

      // Guardas baseadas no usuário (organização + permissões de página).
      final userAsync = ref.read(appUserProvider);
      final user = userAsync.value;
      if (user != null) {
        // Usuário sem organização precisa concluir o onboarding.
        if (!user.isSuperAdmin && !user.temOrganizacao) {
          return isOnboarding ? null : AppRoutes.onboarding;
        }
        if (user.temOrganizacao && isOnboarding) {
          return AppRoutes.dashboard;
        }
        if (user.organizacaoInativa) {
          return isBlocked ? null : AppRoutes.contaBloqueada;
        }
        if (isBlocked) return AppRoutes.dashboard;
        if (location == AppRoutes.superAdmin && !user.isSuperAdmin) {
          return AppRoutes.dashboard;
        }
        final pagina = _paginaFromLocation(location);
        if (pagina != null && !user.podeAcessarPagina(pagina)) {
          return AppRoutes.dashboard;
        }
      }
      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (_, _) => const SplashScreen()),
      GoRoute(path: AppRoutes.login, builder: (_, _) => const LoginScreen()),
      GoRoute(
        path: AppRoutes.onboarding,
        builder: (_, _) => const OnboardingScreen(),
      ),
      GoRoute(
        path: AppRoutes.contaBloqueada,
        builder: (_, _) => const ContaBloqueadaScreen(),
      ),
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
      GoRoute(
        path: AppRoutes.pecas,
        builder: (_, _) => const PecasScreen(),
      ),
      GoRoute(
        path: AppRoutes.clientes,
        builder: (_, _) => const ClientesScreen(),
      ),
      GoRoute(
        path: AppRoutes.fornecedores,
        builder: (_, _) => const FornecedoresScreen(),
      ),
      GoRoute(
        path: AppRoutes.equipe,
        builder: (_, _) => const EquipeScreen(),
      ),
      GoRoute(
        path: AppRoutes.financeiroCentrosCusto,
        builder: (_, _) => const CentrosCustoScreen(),
      ),
      GoRoute(
        path: AppRoutes.financeiroCategorias,
        builder: (_, _) => const CategoriasFinanceirasScreen(),
      ),
      GoRoute(
        path: AppRoutes.financeiroDashboard,
        builder: (_, _) => const DashboardFinanceiroScreen(),
      ),
      GoRoute(
        path: AppRoutes.financeiroContasPagar,
        builder: (_, _) => const ContasScreen(tipo: 'pagar'),
      ),
      GoRoute(
        path: AppRoutes.financeiroContasReceber,
        builder: (_, _) => const ContasScreen(tipo: 'receber'),
      ),
      GoRoute(
        path: AppRoutes.financeiroConciliacao,
        builder: (_, _) => const ConciliacaoBancariaScreen(),
      ),
      GoRoute(
        path: AppRoutes.financeiroIntegracoes,
        builder: (_, _) => const IntegracoesFinanceirasScreen(),
      ),
      GoRoute(
        path: AppRoutes.qualidadeDashboard,
        builder: (_, _) => const QualidadeDashboardScreen(),
      ),
      GoRoute(
        path: AppRoutes.qualidadeEnsaios,
        builder: (_, _) => const QualidadeEnsaiosScreen(),
      ),
      GoRoute(
        path: AppRoutes.qualidadeRastreabilidade,
        builder: (_, _) => const QualidadeRastreabilidadeScreen(),
      ),
      GoRoute(
        path: AppRoutes.fiscalEmitir,
        builder: (_, _) => const EmitirNotaScreen(),
      ),
      GoRoute(
        path: AppRoutes.fiscalNotas,
        builder: (_, _) => const NotasEmitidasScreen(),
      ),
      GoRoute(
        path: AppRoutes.fiscalRecebidas,
        builder: (_, _) => const NotasRecebidasScreen(),
      ),
      GoRoute(
        path: AppRoutes.fiscalConfiguracao,
        builder: (_, _) => const FiscalConfiguracaoScreen(),
      ),
      GoRoute(
        path: AppRoutes.frota,
        builder: (_, _) => const FrotaScreen(),
      ),
      GoRoute(
        path: AppRoutes.suporte,
        builder: (_, _) => const SuporteScreen(),
      ),
      GoRoute(
        path: AppRoutes.configuracoes,
        builder: (_, _) => const ConfiguracoesScreen(),
      ),
      GoRoute(
        path: AppRoutes.minhaFatura,
        builder: (_, _) => const MinhaFaturaScreen(),
      ),
      GoRoute(
        path: AppRoutes.visaoGeral,
        builder: (_, _) => const VisaoGeralScreen(),
      ),
      GoRoute(
        path: AppRoutes.orcamentos,
        builder: (_, _) => const OrcamentosScreen(),
      ),
      GoRoute(
        path: AppRoutes.superAdmin,
        builder: (_, _) => const SuperAdminScreen(),
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
