import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/offline/offline_database.dart';
import '../core/supabase/supabase_service.dart';
import '../models/notificacao.dart';

/// Notificações in-app do usuário (tabela `notificacoes`).
class NotificacoesRepository {
  NotificacoesRepository({SupabaseClient? client})
      : _client = client ?? SupabaseService.client;

  final SupabaseClient _client;

  static const _limite = 100;

  /// Lista as notificações do usuário (cache-first para uso offline).
  Future<List<Notificacao>> list() async {
    final rows = await OfflineDatabase.instance.cachedRows(
      'notificacoes',
      () async {
        final user = _client.auth.currentUser;
        if (user == null) return <Map<String, dynamic>>[];
        return List<Map<String, dynamic>>.from(
          await _client
              .from('notificacoes')
              .select()
              .eq('user_id', user.id)
              .order('created_at', ascending: false)
              .limit(_limite),
        );
      },
    );
    return rows.map((e) => Notificacao.fromMap(e)).toList();
  }

  Future<void> marcarLida(String id) async {
    await _client.from('notificacoes').update({'lida': true}).eq('id', id);
  }

  Future<void> marcarTodasLidas() async {
    final user = _client.auth.currentUser;
    if (user == null) return;
    await _client
        .from('notificacoes')
        .update({'lida': true})
        .eq('user_id', user.id)
        .eq('lida', false);
  }
}
