import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/error_view.dart';
import '../../core/widgets/loading_view.dart';
import '../../models/notificacao.dart';
import '../../providers/notificacoes_providers.dart';

/// Central de notificações in-app — espelha o sino do sistema web.
class NotificacoesScreen extends ConsumerWidget {
  const NotificacoesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(notificacoesProvider);
    final naoLidas = ref.watch(notificacoesNaoLidasProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notificações'),
        actions: [
          if (naoLidas > 0)
            TextButton(
              onPressed: () async {
                await ref.read(notificacoesRepositoryProvider).marcarTodasLidas();
                ref.invalidate(notificacoesProvider);
              },
              child: const Text('Marcar lidas'),
            ),
        ],
      ),
      body: async.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(
          message: e.toString(),
          onRetry: () => ref.invalidate(notificacoesProvider),
        ),
        data: (lista) {
          if (lista.isEmpty) {
            return const EmptyState(
              icon: Icons.notifications_none,
              title: 'Nenhuma notificação',
              message: 'Você está em dia. Avisos de produção, montagem e '
                  'atualizações aparecerão aqui.',
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.refresh(notificacoesProvider.future),
            child: ListView.separated(
              itemCount: lista.length,
              separatorBuilder: (_, _) => const Divider(height: 1, indent: 64),
              itemBuilder: (context, i) => _Tile(
                notificacao: lista[i],
                onTap: () async {
                  if (!lista[i].lida) {
                    await ref
                        .read(notificacoesRepositoryProvider)
                        .marcarLida(lista[i].id);
                    ref.invalidate(notificacoesProvider);
                  }
                  final obraId = lista[i].obraId;
                  if (obraId != null && context.mounted) {
                    context.push('/obras/$obraId');
                  }
                },
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.notificacao, required this.onTap});

  final Notificacao notificacao;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final n = notificacao;
    return ListTile(
      onTap: onTap,
      tileColor: n.lida ? null : AppColors.info.withValues(alpha: 0.06),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: _cor(n.tipo).withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(_icone(n.tipo), color: _cor(n.tipo), size: 20),
      ),
      title: Text(
        n.titulo,
        style: TextStyle(
          fontWeight: n.lida ? FontWeight.w500 : FontWeight.w700,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if ((n.descricao ?? '').isNotEmpty)
            Text(n.descricao!,
                maxLines: 2, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Text(
            Formatters.dataHoraBr(n.createdAt),
            style: const TextStyle(fontSize: 11),
          ),
        ],
      ),
      isThreeLine: (n.descricao ?? '').isNotEmpty,
      trailing: n.lida
          ? null
          : Container(
              width: 9,
              height: 9,
              decoration: const BoxDecoration(
                color: AppColors.info,
                shape: BoxShape.circle,
              ),
            ),
    );
  }

  static IconData _icone(String tipo) => switch (tipo) {
        'producao' => Icons.precision_manufacturing_outlined,
        'carregamento' => Icons.local_shipping_outlined,
        'aguardando' => Icons.hourglass_empty,
        'montagem' => Icons.handyman_outlined,
        'manual' => Icons.edit_note,
        'alerta' => Icons.warning_amber_outlined,
        _ => Icons.notifications_outlined,
      };

  static Color _cor(String tipo) => switch (tipo) {
        'producao' => AppColors.primary,
        'carregamento' => AppColors.info,
        'aguardando' => AppColors.warning,
        'montagem' => AppColors.success,
        'manual' => AppColors.mutedForeground,
        'alerta' => AppColors.destructive,
        _ => AppColors.info,
      };
}
