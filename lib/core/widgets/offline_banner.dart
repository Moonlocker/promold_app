import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../offline/offline_providers.dart';
import '../offline/sync_service.dart';
import '../theme/app_colors.dart';

/// Faixa global que indica o modo offline e o estado da sincronização.
///
/// Fica oculta quando está tudo online e não há pendências.
class OfflineBanner extends ConsumerWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final online = ref.watch(onlineProvider).value ?? true;
    final sync = ref.watch(syncStateProvider).value ?? SyncState.initial;
    final readerPending = ref.watch(readerPendingProvider).value ?? 0;
    final pending = sync.pending + readerPending;

    if (online && pending == 0 && !sync.syncing) {
      return const SizedBox.shrink();
    }

    final Color color;
    final IconData icon;
    final String texto;
    if (!online) {
      color = AppColors.warning;
      icon = Icons.cloud_off;
      texto = pending > 0
          ? 'Offline — $pending alteração(ões) aguardando'
          : 'Modo offline — usando dados salvos no aparelho';
    } else if (sync.syncing) {
      color = AppColors.info;
      icon = Icons.sync;
      texto = 'Sincronizando alterações...';
    } else {
      color = AppColors.info;
      icon = Icons.cloud_upload_outlined;
      texto = '$pending alteração(ões) pendente(s)';
    }

    return Material(
      color: color.withValues(alpha: 0.12),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  texto,
                  style: TextStyle(
                    color: color,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (online && !sync.syncing && pending > 0)
                TextButton(
                  onPressed: () => syncEverything(ref),
                  style: TextButton.styleFrom(
                    foregroundColor: color,
                    visualDensity: VisualDensity.compact,
                  ),
                  child: const Text('Sincronizar'),
                ),
              if (!online) Icon(Icons.wifi_off, size: 14, color: color),
            ],
          ),
        ),
      ),
    );
  }
}
