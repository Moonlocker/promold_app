import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/notificacao.dart';
import '../repositories/notificacoes_repository.dart';
import 'auth_providers.dart';
import 'supabase_providers.dart';

final notificacoesRepositoryProvider = Provider<NotificacoesRepository>(
  (ref) => NotificacoesRepository(client: ref.watch(supabaseClientProvider)),
);

/// Notificações do usuário autenticado.
final notificacoesProvider = FutureProvider<List<Notificacao>>((ref) async {
  final user = await ref.watch(appUserProvider.future);
  if (user == null) return <Notificacao>[];
  return ref.watch(notificacoesRepositoryProvider).list();
});

/// Quantidade de notificações não lidas (para o badge do sino).
final notificacoesNaoLidasProvider = Provider<int>((ref) {
  final list = ref.watch(notificacoesProvider).value ?? const <Notificacao>[];
  return list.where((n) => !n.lida).length;
});
