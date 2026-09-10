import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/supabase/supabase_service.dart';
import '../models/obra_historico.dart';

/// Histórico da obra, logs de planejamento, monitoramento e notificações.
class ObraHistoricoRepository {
  ObraHistoricoRepository({SupabaseClient? client})
      : _client = client ?? SupabaseService.client;

  final SupabaseClient _client;

  Future<List<ObraHistorico>> listHistorico(String obraId) async {
    final rows = await _client
        .from('obras_historico')
        .select()
        .eq('obra_id', obraId)
        .order('created_at', ascending: false);
    return rows
        .map((e) => ObraHistorico.fromMap(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<void> addManual(Map<String, dynamic> data) async {
    await _client.from('obras_historico').insert(data);
  }

  Future<void> updateManual(String id, Map<String, dynamic> data) async {
    await _client.from('obras_historico').update(data).eq('id', id);
  }

  Future<void> deleteHistorico(String id) async {
    await _client.from('obras_historico').delete().eq('id', id);
  }

  /// Histórico + logs de planejamento mesclados (mais recentes primeiro).
  Future<List<ObraHistorico>> listMerged(String obraId) async {
    final historico = await listHistorico(obraId);
    final logs = await _listPlanejamentoLogs(obraId);

    final merged = <ObraHistorico>[...historico, ...logs]
      ..sort((a, b) {
        final da = a.createdAt?.toIso8601String() ?? '';
        final db = b.createdAt?.toIso8601String() ?? '';
        return db.compareTo(da);
      });
    return merged;
  }

  Future<List<ObraHistorico>> _listPlanejamentoLogs(String obraId) async {
    final rows = await _client
        .from('planejamento_logs')
        .select(
            'id, acao, descricao, detalhes, created_at, usuario_id, tipo_planejamento, data_referencia')
        .eq('obra_id', obraId)
        .order('created_at', ascending: false)
        .limit(500);

    final userIds = rows
        .map((e) => e['usuario_id'])
        .whereType<String>()
        .toSet()
        .toList();

    final nomes = <String, String>{};
    if (userIds.isNotEmpty) {
      final perfis = await _client
          .from('profiles')
          .select('user_id, nome, email')
          .inFilter('user_id', userIds);
      for (final p in perfis) {
        final uid = p['user_id'] as String?;
        if (uid == null) continue;
        nomes[uid] = (p['nome'] as String?)?.isNotEmpty == true
            ? p['nome'] as String
            : ((p['email'] as String?) ?? 'Usuário');
      }
    }

    return rows.map((e) {
      final map = Map<String, dynamic>.from(e);
      final dataRef = map['data_referencia'] as String?;
      return ObraHistorico(
        id: 'plan-${map['id']}',
        obraId: obraId,
        tipo: 'planejamento',
        descricao: (map['descricao'] as String?) ??
            'Planejamento ${map['tipo_planejamento']} ${map['acao']}',
        detalhes: dataRef != null ? 'Data: $dataRef' : null,
        responsavel: nomes[map['usuario_id']],
        createdAt: DateTime.tryParse(map['created_at'] as String? ?? ''),
        source: 'planejamento',
      );
    }).toList();
  }

  // ------------------------------------------------------- Monitoramento
  Future<ObraMonitoramento?> getMonitoramento(
    String obraId,
    String userId,
  ) async {
    final row = await _client
        .from('obra_monitoramento')
        .select()
        .eq('obra_id', obraId)
        .eq('user_id', userId)
        .maybeSingle();
    if (row == null) return null;
    return ObraMonitoramento.fromMap(Map<String, dynamic>.from(row));
  }

  Future<void> upsertMonitoramento(
    String obraId,
    String userId,
    Map<String, dynamic> flags,
  ) async {
    final existing = await _client
        .from('obra_monitoramento')
        .select('id')
        .eq('obra_id', obraId)
        .eq('user_id', userId)
        .maybeSingle();
    if (existing != null) {
      await _client
          .from('obra_monitoramento')
          .update(flags)
          .eq('id', existing['id'] as String);
    } else {
      await _client.from('obra_monitoramento').insert({
        'obra_id': obraId,
        'user_id': userId,
        ...flags,
      });
    }
  }

  /// Porte de `createNotificationsForObra` (apenas para registros manuais).
  Future<void> createNotificationsForObra({
    required String obraId,
    required String obraNome,
    required String tipo,
    required String descricao,
  }) async {
    const fieldMap = {
      'producao': 'notif_producao',
      'carregamento': 'notif_carregamento',
      'aguardando': 'notif_aguardando',
      'montagem': 'notif_montagem',
      'manual': 'notif_manual',
    };
    final field = fieldMap[tipo];
    if (field == null) return;

    final monitoramentos = await _client
        .from('obra_monitoramento')
        .select()
        .eq('obra_id', obraId)
        .eq(field, true);
    if (monitoramentos.isEmpty) return;

    const tituloMap = {
      'producao': 'Produção',
      'carregamento': 'Carregamento',
      'aguardando': 'Aguardando',
      'montagem': 'Montagem',
      'manual': 'Atualização',
    };
    final titulo = '${tituloMap[tipo]}: $obraNome';

    final notificacoes = monitoramentos
        .map((m) => {
              'user_id': m['user_id'],
              'obra_id': obraId,
              'tipo': tipo,
              'titulo': titulo,
              'descricao': descricao,
            })
        .toList();
    await _client.from('notificacoes').insert(notificacoes);
  }
}
