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
