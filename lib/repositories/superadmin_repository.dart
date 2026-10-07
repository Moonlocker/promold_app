import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/supabase/supabase_service.dart';
import '../models/superadmin.dart';

/// Painel SuperAdmin (plataforma): organizações, saúde e auditoria.
class SuperAdminRepository {
  SuperAdminRepository({SupabaseClient? client})
      : _client = client ?? SupabaseService.client;

  final SupabaseClient _client;

  /// Saúde operacional de todas as organizações (RPC `saude_operacional_orgs`).
  Future<List<SaudeOrg>> saudeOperacional() async {
    final rows = await _client.rpc('saude_operacional_orgs');
    return (rows as List)
        .map((e) => SaudeOrg.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<List<Map<String, dynamic>>> listOrganizacoes() async {
    final rows =
        await _client.from('organizacoes').select().order('nome');
    return rows.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Future<void> updateOrganizacao(String id, Map<String, dynamic> data) async {
    await _client.from('organizacoes').update(data).eq('id', id);
  }

  Future<List<AuditLogSuper>> listAuditLogs({int limit = 100}) async {
    final rows = await _client
        .from('superadmin_audit_logs')
        .select()
        .order('created_at', ascending: false)
        .limit(limit);
    return rows
        .map((e) => AuditLogSuper.fromMap(Map<String, dynamic>.from(e)))
        .toList();
  }

  // ------------------------------------------------------------- Usuários
  Future<List<Map<String, dynamic>>> listProfiles() async {
    final rows = await _client.from('profiles').select().order('nome');
    return rows.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Future<List<Map<String, dynamic>>> listUserRoles() async {
    final rows = await _client.from('user_roles').select();
    return rows.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Future<Map<String, dynamic>> createUser(Map<String, dynamic> body) async {
    final res = await _client.functions.invoke('create-user', body: body);
    final data = res.data;
    if (data is Map && data['error'] != null) {
      throw Exception(data['error']);
    }
    return data is Map ? Map<String, dynamic>.from(data) : {};
  }

  Future<void> updateProfile(String userId, Map<String, dynamic> data) async {
    await _client.from('profiles').update(data).eq('user_id', userId);
  }

  Future<void> upsertUserRole(String userId, String role) async {
    final existing = await _client
        .from('user_roles')
        .select('id')
        .eq('user_id', userId)
        .maybeSingle();
    if (existing != null) {
      await _client
          .from('user_roles')
          .update({'role': role}).eq('user_id', userId);
    } else {
      await _client
          .from('user_roles')
          .insert({'user_id': userId, 'role': role});
    }
  }

  Future<void> impersonateUser(String targetUserId) async {
    await _client.functions.invoke('impersonate-user', body: {
      'target_user_id': targetUserId,
      'redirect_to': null,
    });
  }

  Future<void> registrarAudit({
    required String acao,
    String? alvoTipo,
    String? alvoId,
    String? alvoDescricao,
  }) async {
    await _client.rpc('registrar_audit_super', params: {
      '_acao': acao,
      '_alvo_tipo': alvoTipo,
      '_alvo_id': alvoId,
      '_alvo_descricao': alvoDescricao,
    });
  }

  // --------------------------------------------------- Módulos e páginas
  Future<List<Map<String, dynamic>>> listModulos() async {
    final rows = await _client.from('modulos').select().order('ordem');
    return rows.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Future<List<Map<String, dynamic>>> listPaginas() async {
    final rows = await _client
        .from('paginas')
        .select()
        .order('categoria')
        .order('ordem');
    return rows.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Future<List<Map<String, dynamic>>> listModulosPaginas() async {
    final rows = await _client
        .from('modulos_paginas')
        .select('modulo_id, pagina_slug');
    return rows.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Future<void> saveModulo(Map<String, dynamic> data, {String? id}) async {
    if (id != null) {
      await _client.from('modulos').update(data).eq('id', id);
    } else {
      await _client.from('modulos').insert(data);
    }
  }

  Future<void> savePagina(Map<String, dynamic> data, {String? id}) async {
    if (id != null) {
      await _client.from('paginas').update(data).eq('id', id);
    } else {
      await _client.from('paginas').insert(data);
    }
  }

  Future<void> deleteModulo(String id) async {
    await _client.from('modulos_paginas').delete().eq('modulo_id', id);
    await _client.from('modulos').delete().eq('id', id);
  }

  Future<void> deletePagina(String id) async {
    await _client.from('paginas').delete().eq('id', id);
  }

  Future<void> toggleVinculoModulo({
    required String moduloId,
    required String paginaSlug,
    required bool vincular,
  }) async {
    if (vincular) {
      await _client.from('modulos_paginas').insert({
        'modulo_id': moduloId,
        'pagina_slug': paginaSlug,
      });
    } else {
      await _client
          .from('modulos_paginas')
          .delete()
          .eq('modulo_id', moduloId)
          .eq('pagina_slug', paginaSlug);
    }
  }

  // ------------------------------------------------------- Feature flags
  Future<List<Map<String, dynamic>>> listFeatureFlags() async {
    final rows = await _client
        .from('feature_flags')
        .select()
        .order('created_at', ascending: false);
    return rows.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Future<List<Map<String, dynamic>>> listFeatureFlagOverrides(
    String flagId,
  ) async {
    final rows = await _client
        .from('organizacao_feature_flags')
        .select()
        .eq('feature_flag_id', flagId);
    return rows.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Future<void> saveFeatureFlag(Map<String, dynamic> data, {String? id}) async {
    if (id != null) {
      await _client.from('feature_flags').update(data).eq('id', id);
    } else {
      await _client.from('feature_flags').insert(data);
    }
  }

  Future<void> deleteFeatureFlag(String id) async {
    await _client
        .from('organizacao_feature_flags')
        .delete()
        .eq('feature_flag_id', id);
    await _client.from('feature_flags').delete().eq('id', id);
  }

  Future<void> setFeatureFlagOverride({
    required String organizacaoId,
    required String flagId,
    required bool? enabled,
  }) async {
    if (enabled == null) {
      await _client
          .from('organizacao_feature_flags')
          .delete()
          .eq('organizacao_id', organizacaoId)
          .eq('feature_flag_id', flagId);
    } else {
      await _client.from('organizacao_feature_flags').upsert({
        'organizacao_id': organizacaoId,
        'feature_flag_id': flagId,
        'enabled': enabled,
      }, onConflict: 'organizacao_id,feature_flag_id');
    }
  }

  // -------------------------------------------------------- Inadimplência
  Future<List<Map<String, dynamic>>> listFaturasVencidas() async {
    final hoje = DateTime.now();
    final iso = '${hoje.year.toString().padLeft(4, '0')}-'
        '${hoje.month.toString().padLeft(2, '0')}-'
        '${hoje.day.toString().padLeft(2, '0')}';
    final rows = await _client
        .from('faturas_saas')
        .select()
        .neq('status', 'paga')
        .neq('status', 'cancelada')
        .lt('data_vencimento', iso)
        .order('data_vencimento');
    return rows.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Future<void> marcarFaturasPagas(List<String> ids) async {
    if (ids.isEmpty) return;
    final hoje = DateTime.now().toIso8601String();
    await _client.from('faturas_saas').update({
      'status': 'paga',
      'data_pagamento': hoje,
      'metodo_pagamento': 'manual',
    }).inFilter('id', ids);
  }

  Future<void> suspenderOrganizacoes(List<String> orgIds, String motivo) async {
    if (orgIds.isEmpty) return;
    await _client.from('organizacoes').update({
      'ativo': false,
      'bloqueio_tipo': 'pagamento_pendente',
      'bloqueio_motivo': motivo,
    }).inFilter('id', orgIds);
  }

  Future<void> criarNotificacaoOrg({
    required String organizacaoId,
    required String titulo,
    required String descricao,
    String tipo = 'financeiro',
  }) async {
    try {
      await _client.rpc('criar_notificacao_org', params: {
        '_org_id': organizacaoId,
        '_titulo': titulo,
        '_descricao': descricao,
        '_tipo': tipo,
      });
    } catch (_) {
      // RPC pode não existir; ignora silenciosamente.
    }
  }
}
