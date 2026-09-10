import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/supabase/supabase_service.dart';

/// Configurações chave/valor da organização (tabela `configuracoes`).
/// Usadas para cores/pesos de status, entre outras preferências.
class ConfiguracoesRepository {
  ConfiguracoesRepository({SupabaseClient? client})
      : _client = client ?? SupabaseService.client;

  final SupabaseClient _client;

  Future<Map<String, String>> load() async {
    final rows = await _client.from('configuracoes').select('chave, valor');
    final config = <String, String>{};
    for (final row in rows) {
      final chave = row['chave'] as String?;
      if (chave == null) continue;
      config[chave] = (row['valor'] as String?) ?? '';
    }
    return config;
  }
}
