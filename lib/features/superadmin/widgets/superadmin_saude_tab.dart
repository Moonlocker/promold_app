import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../models/superadmin.dart';
import '../../../providers/superadmin_providers.dart';

/// SuperAdmin — aba Saúde Operacional.
class SuperAdminSaudeTab extends ConsumerWidget {
  const SuperAdminSaudeTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(saudeOrgsProvider);
    return async.when(
      loading: () => const LoadingView(),
      error: (e, _) => Center(child: Text('Erro: $e')),
      data: (orgs) {
        if (orgs.isEmpty) {
          return const EmptyState(
              icon: Icons.monitor_heart_outlined,
              title: 'Sem dados de saúde');
        }
        final ordenadas = [...orgs]
          ..sort((a, b) => a.healthScore.compareTo(b.healthScore));
        final criticas = ordenadas.where((o) => o.healthScore < 40).length;
        final atencao = ordenadas
            .where((o) => o.healthScore >= 40 && o.healthScore < 70)
            .length;
        final saudaveis = ordenadas.where((o) => o.healthScore >= 70).length;

        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(saudeOrgsProvider),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            children: [
              Row(
                children: [
                  Expanded(
                    child: _Box('Críticas', criticas, AppColors.destructive),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _Box('Atenção', atencao, AppColors.warning),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _Box('Saudáveis', saudaveis, AppColors.success),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ...ordenadas.map((o) => _OrgSaudeCard(org: o)),
            ],
          ),
        );
      },
    );
  }
}

class _OrgSaudeCard extends StatelessWidget {
  const _OrgSaudeCard({required this.org});

  final SaudeOrg org;

  @override
  Widget build(BuildContext context) {
    final cor = org.healthScore >= 70
        ? AppColors.success
        : org.healthScore >= 40
            ? AppColors.warning
            : AppColors.destructive;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(org.nome,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: cor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text('${org.healthScore}',
                      style: TextStyle(
                          fontWeight: FontWeight.w700, color: cor)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 14,
              runSpacing: 4,
              children: [
                _info(Icons.local_shipping_outlined,
                    '${Formatters.numero(org.m3Ultimos30, 1)} m³/30d'),
                _info(Icons.business_outlined, '${org.obrasAtivas} obras'),
                _info(Icons.people_outline,
                    '${org.usuariosAtivos30}/${org.totalUsuarios} ativos'),
                _info(Icons.receipt_long_outlined,
                    '${org.faturasAtrasadas} fat. atrasadas'),
                _info(Icons.schedule_outlined,
                    '${org.diasSemProducao}d sem produção'),
                if (!org.ativo)
                  const _Chip('inativa', AppColors.mutedForeground),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _info(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: AppColors.mutedForeground),
        const SizedBox(width: 3),
        Text(text, style: const TextStyle(fontSize: 11.5)),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.label, this.color);

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label,
          style: TextStyle(fontSize: 10.5, color: color)),
    );
  }
}

class _Box extends StatelessWidget {
  const _Box(this.label, this.valor, this.cor);

  final String label;
  final int valor;
  final Color cor;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Column(
          children: [
            Text('$valor',
                style: TextStyle(
                    fontSize: 20, fontWeight: FontWeight.w700, color: cor)),
            Text(label,
                style: const TextStyle(
                    fontSize: 11, color: AppColors.mutedForeground)),
          ],
        ),
      ),
    );
  }
}
