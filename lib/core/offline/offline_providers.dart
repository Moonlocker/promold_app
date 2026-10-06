import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/supabase_providers.dart';
import '../supabase/supabase_service.dart';
import 'connectivity.dart';
import 'offline_database.dart';
import 'sync_service.dart';

/// Banco local de cache/outbox.
final offlineDatabaseProvider = Provider<OfflineDatabase>(
  (ref) => OfflineDatabase.instance,
);

/// Conectividade atual (true = online).
final onlineProvider = StreamProvider<bool>((ref) {
  final controller = StreamController<bool>();
  controller.add(AppConnectivity.instance.isOnline);
  final sub = AppConnectivity.instance.stream.listen(controller.add);
  ref.onDispose(() {
    sub.cancel();
    controller.close();
  });
  return controller.stream;
});

/// Sincronizador (outbox). Começa a drenar a fila sempre que a conexão volta.
final syncServiceProvider = Provider<SyncService>((ref) {
  final service = SyncService(
    db: OfflineDatabase.instance,
    client: SupabaseService.client,
  );

  final sub = AppConnectivity.instance.stream.listen((online) {
    if (online) service.flush();
  });
  ref.onDispose(sub.cancel);
  ref.onDispose(service.dispose);

  service.refreshPending();
  return service;
});

/// Estado observável da sincronização (pendências, sincronizando, última vez).
final syncStateProvider = StreamProvider<SyncState>((ref) {
  final service = ref.watch(syncServiceProvider);
  return service.stream;
});

/// Quantidade de leituras (QR) feitas offline aguardando sincronização.
final readerPendingProvider = StreamProvider<int>((ref) async* {
  final service = ref.watch(leitorServiceProvider);
  yield await service.pendingLeiturasCount();
  await for (final _ in service.changes) {
    yield await service.pendingLeiturasCount();
  }
});

/// Sincroniza tudo: mutações CRUD (outbox) + leituras offline dos leitores.
Future<void> syncEverything(WidgetRef ref) async {
  await ref.read(syncServiceProvider).flush();
  await ref.read(leitorServiceProvider).syncLeituras();
}
