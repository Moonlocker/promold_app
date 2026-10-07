import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/superadmin.dart';
import 'supabase_providers.dart';

/// Saúde operacional de todas as organizações.
final saudeOrgsProvider = FutureProvider<List<SaudeOrg>>(
  (ref) => ref.watch(superAdminRepositoryProvider).saudeOperacional(),
);

/// Todas as organizações da plataforma.
final todasOrganizacoesProvider = FutureProvider<List<Map<String, dynamic>>>(
  (ref) => ref.watch(superAdminRepositoryProvider).listOrganizacoes(),
);

/// Logs de auditoria do superadmin.
final auditLogsProvider = FutureProvider<List<AuditLogSuper>>(
  (ref) => ref.watch(superAdminRepositoryProvider).listAuditLogs(),
);

/// Todos os perfis (usuários) da plataforma.
final profilesAdminProvider = FutureProvider<List<Map<String, dynamic>>>(
  (ref) => ref.watch(superAdminRepositoryProvider).listProfiles(),
);

/// Papéis (user_roles) de todos os usuários.
final userRolesAdminProvider = FutureProvider<List<Map<String, dynamic>>>(
  (ref) => ref.watch(superAdminRepositoryProvider).listUserRoles(),
);

/// Módulos da plataforma.
final modulosAdminProvider = FutureProvider<List<Map<String, dynamic>>>(
  (ref) => ref.watch(superAdminRepositoryProvider).listModulos(),
);

/// Páginas da plataforma.
final paginasAdminProvider = FutureProvider<List<Map<String, dynamic>>>(
  (ref) => ref.watch(superAdminRepositoryProvider).listPaginas(),
);

/// Vínculos módulo → página.
final modulosPaginasAdminProvider =
    FutureProvider<List<Map<String, dynamic>>>(
  (ref) => ref.watch(superAdminRepositoryProvider).listModulosPaginas(),
);

/// Feature flags da plataforma.
final featureFlagsAdminProvider = FutureProvider<List<Map<String, dynamic>>>(
  (ref) => ref.watch(superAdminRepositoryProvider).listFeatureFlags(),
);

/// Overrides de uma feature flag por organização.
final featureFlagOverridesProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>(
  (ref, flagId) => ref
      .watch(superAdminRepositoryProvider)
      .listFeatureFlagOverrides(flagId),
);

/// Faturas SaaS vencidas (inadimplência).
final faturasVencidasProvider =
    FutureProvider<List<Map<String, dynamic>>>(
  (ref) => ref.watch(superAdminRepositoryProvider).listFaturasVencidas(),
);

/// Planos da plataforma.
final planosAdminProvider = FutureProvider<List<Map<String, dynamic>>>(
  (ref) => ref.watch(superAdminRepositoryProvider).listPlanos(),
);

/// Faixas de m³ de um plano.
final planoFaixasProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>(
  (ref, planoId) =>
      ref.watch(superAdminRepositoryProvider).listPlanoFaixas(planoId),
);

/// Módulos vinculados a um plano.
final planoModulosProvider = FutureProvider.family<List<String>, String>(
  (ref, planoId) =>
      ref.watch(superAdminRepositoryProvider).listPlanoModulos(planoId),
);

/// Configurações globais.
final configGlobaisProvider =
    FutureProvider<List<Map<String, dynamic>>>(
  (ref) => ref.watch(superAdminRepositoryProvider).listConfigGlobais(),
);

/// Configurações secretas.
final configSecretasProvider =
    FutureProvider<List<Map<String, dynamic>>>(
  (ref) => ref.watch(superAdminRepositoryProvider).listConfigSecretas(),
);

/// Faturas SaaS de um mês (ano, mês).
final faturasMesProvider =
    FutureProvider.family<List<Map<String, dynamic>>, (int, int)>(
  (ref, key) =>
      ref.watch(superAdminRepositoryProvider).listFaturas(key.$1, key.$2),
);
