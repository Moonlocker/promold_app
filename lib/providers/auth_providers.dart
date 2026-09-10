import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/app_user.dart';
import '../models/dashboard_metrics.dart';
import '../models/obra.dart';
import 'supabase_providers.dart';

/// Sessão atual (emite o valor inicial e as mudanças de autenticação).
final sessionProvider = StreamProvider<Session?>(
  (ref) => ref.watch(authServiceProvider).sessionStream(),
);

/// Usuário autenticado enriquecido com perfil, organização e permissões.
final appUserProvider = FutureProvider<AppUser?>((ref) async {
  final session = await ref.watch(sessionProvider.future);
  if (session == null) return null;
  return ref.watch(authRepositoryProvider).loadAppUser(session.user);
});

/// Métricas do dashboard (só carrega quando há usuário autenticado).
final dashboardMetricsProvider = FutureProvider<DashboardMetrics>((ref) async {
  final user = await ref.watch(appUserProvider.future);
  if (user == null) return DashboardMetrics.empty;
  return ref.watch(dashboardRepositoryProvider).load();
});

/// Lista de obras da organização do usuário.
final obrasListProvider = FutureProvider<List<Obra>>((ref) async {
  final user = await ref.watch(appUserProvider.future);
  if (user == null) return <Obra>[];
  return ref.watch(obrasRepositoryProvider).list();
});
