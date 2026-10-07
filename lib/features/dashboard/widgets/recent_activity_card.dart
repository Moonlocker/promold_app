import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../models/obra_historico.dart';
import '../../../providers/dashboard_providers.dart';

/// Feed "Atividades Recentes" (últimas 24h) do Dashboard.
class RecentActivityCard extends ConsumerWidget {
  const RecentActivityCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(dashboardRecentActivityProvider);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text('Atividades Recentes',
                      style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w700)),
                ),
                const Text('últimas 24h',
                    style: TextStyle(
                        fontSize: 10.5, color: AppColors.mutedForeground)),
              ],
            ),
            const SizedBox(height: 10),
            async.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Text('Erro: $e',
                  style: const TextStyle(color: AppColors.mutedForeground)),
              data: (itens) {
                final lista = itens.take(20).toList();
                if (lista.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Text('Nenhuma atividade recente.',
                        style: TextStyle(color: AppColors.mutedForeground)),
                  );
                }
                return Column(
                  children: [
                    for (final item in lista) _ActivityTile(item: item),
                    const SizedBox(height: 6),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => context.go(AppRoutes.obras),
                        child: const Text('Ver todas as atividades →'),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ActivityTile extends StatelessWidget {
  const _ActivityTile({required this.item});

  final ObraHistorico item;

  static const _config = <String, (IconData, Color, String)>{
    'producao': (Icons.inventory_2_outlined, AppColors.success, 'Produção'),
    'despacho': (Icons.local_shipping_outlined, AppColors.info, 'Despacho'),
    'montagem': (Icons.build_outlined, AppColors.primary, 'Montagem'),
    'etapa': (Icons.history, AppColors.warning, 'Etapa'),
    'observacao': (Icons.chat_bubble_outline, AppColors.mutedForeground, 'Observação'),
    'foto': (Icons.image_outlined, AppColors.primary, 'Foto'),
    'anexo': (Icons.attach_file, AppColors.info, 'Anexo'),
    'manual': (Icons.description_outlined, AppColors.mutedForeground, 'Manual'),
    'auditoria': (Icons.error_outline, AppColors.destructive, 'Auditoria'),
    'planejamento': (Icons.event_available_outlined, AppColors.warning, 'Planejamento'),
  };

  @override
  Widget build(BuildContext context) {
    final cfg = _config[item.tipo] ??
        (Icons.description_outlined, AppColors.mutedForeground, 'Registro');
    return InkWell(
      onTap: item.obraId.isEmpty
          ? null
          : () => context.push(AppRoutes.obraDetalhe(item.obraId)),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: cfg.$2.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(cfg.$1, size: 14, color: cfg.$2),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${item.descricao}'
                    '${item.obraNome != null ? ' · ${item.obraNome}' : ''}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12.5),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${item.responsavel ?? 'Sistema'} • ${Formatters.tempoAtras(item.createdAt)}',
                    style: const TextStyle(
                        fontSize: 10.5, color: AppColors.mutedForeground),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
