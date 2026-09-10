import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/stat_card.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../providers/auth_providers.dart';

/// Dashboard inicial, espelhando as métricas de `src/pages/Dashboard.tsx`.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metricsAsync = ref.watch(dashboardMetricsProvider);
    final userAsync = ref.watch(appUserProvider);

    final nome = userAsync.value?.displayName ?? '';

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Dashboard'),
            Text(
              nome.isEmpty ? 'Carregando...' : 'Olá, $nome',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: AppColors.mutedForeground,
              ),
            ),
          ],
        ),
      ),
      body: metricsAsync.when(
        loading: () => const LoadingView(message: 'Carregando indicadores...'),
        error: (error, _) => ErrorView(
          message: error.toString(),
          onRetry: () => ref.invalidate(dashboardMetricsProvider),
        ),
        data: (data) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(dashboardMetricsProvider),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  Expanded(
                    child: StatCard(
                      title: 'Obras Ativas',
                      value: '${data.obrasAtivas}',
                      subtitle: 'em produção',
                      icon: Icons.business_outlined,
                      color: AppColors.primary,
                      onTap: () => context.go(AppRoutes.obras),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: StatCard(
                      title: 'Produção Hoje',
                      value: '${data.producaoHoje}',
                      subtitle: 'peças concretadas',
                      icon: Icons.inventory_2_outlined,
                      color: AppColors.success,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: StatCard(
                      title: 'Peças Pendentes',
                      value: '${data.pecasPendentes}',
                      subtitle: 'em todas as obras',
                      icon: Icons.pending_actions_outlined,
                      color: AppColors.warning,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: StatCard(
                      title: 'Concreto Semana',
                      value: '${data.concretoSemanaM3.toStringAsFixed(1)}m³',
                      subtitle: 'consumido',
                      icon: Icons.water_drop_outlined,
                      color: AppColors.info,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Obras Prioritárias',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  TextButton(
                    onPressed: () => context.go(AppRoutes.obras),
                    child: const Text('Ver todas'),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              if (data.obrasPrioritarias.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    'Nenhuma obra ativa no momento.',
                    style: TextStyle(color: AppColors.mutedForeground),
                  ),
                )
              else
                ...data.obrasPrioritarias.map(
                  (obra) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  '#${obra.prioridade}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.mutedForeground,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                StatusBadge(status: obra.status),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              obra.nome,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              obra.cliente,
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.mutedForeground,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
