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
}
