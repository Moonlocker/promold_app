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
