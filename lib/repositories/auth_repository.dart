import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/supabase/supabase_service.dart';
import '../models/app_user.dart';
import '../models/organizacao.dart';
import '../models/permissoes.dart';
import '../models/profile.dart';

/// Monta o [AppUser] a partir das mesmas tabelas/RPC usadas pelo webapp:
/// `profiles`, `user_roles`, `organizacoes` e `user_paginas_visiveis`.
class AuthRepository {
  AuthRepository({SupabaseClient? client})
      : _client = client ?? SupabaseService.client;

  final SupabaseClient _client;

  Future<AppUser?> loadAppUser(User authUser) async {
    final profile = await _loadProfile(authUser.id);
    final role = await _loadRole(authUser.id);
    final isSuperAdmin = role == 'superadmin';

    Organizacao? organizacao;
    if (profile?.organizacaoId != null) {
      organizacao = await _loadOrganizacao(profile!.organizacaoId!);
    }

    final paginas = await _loadPaginasVisiveis(authUser.id, isSuperAdmin);
    final permissoes = await _loadPermissoes(role, isSuperAdmin);

    return AppUser(
      authUser: authUser,
      role: role,
      profile: profile,
      organizacao: organizacao,
      isSuperAdmin: isSuperAdmin,
      paginasVisiveis: paginas,
      permissoes: permissoes,
    );
  }

  Future<Profile?> _loadProfile(String userId) async {
    final data = await _client
        .from('profiles')
        .select()
        .eq('user_id', userId)
        .maybeSingle();
    if (data == null) return null;
    return Profile.fromMap(Map<String, dynamic>.from(data));
  }

  Future<String> _loadRole(String userId) async {
    final data = await _client
        .from('user_roles')
        .select('role')
        .eq('user_id', userId)
        .maybeSingle();
    return (data?['role'] as String?) ?? 'visualizador';
  }

  Future<Organizacao?> _loadOrganizacao(String orgId) async {
    final data = await _client
        .from('organizacoes')
        .select()
        .eq('id', orgId)
        .maybeSingle();
    if (data == null) return null;
    return Organizacao.fromMap(Map<String, dynamic>.from(data));
  }

  /// Mesma regra do webapp: `user_paginas_visiveis` + wildcard para superadmin.
  Future<Set<String>> _loadPaginasVisiveis(
    String userId,
    bool isSuperAdmin,
  ) async {
    final result = await _client.rpc(
      'user_paginas_visiveis',
      params: {'_user_id': userId},
    );
    final set = <String>{};
    if (result is List) {
      for (final row in result) {
        if (row is Map && row['pagina_slug'] != null) {
          set.add(row['pagina_slug'] as String);
        }
      }
    }
    if (isSuperAdmin) set.add('*');
    return set;
  }

  /// Direitos granulares (criar/editar/excluir) do papel do usuário.
  /// Prefere linhas específicas da organização sobre as globais.
  Future<Map<String, PermissaoPagina>> _loadPermissoes(
    String role,
    bool isSuperAdmin,
  ) async {
    if (isSuperAdmin || role == 'admin') {
      return const <String, PermissaoPagina>{};
    }
    final meProfile = await _client
        .from('profiles')
        .select('organizacao_id')
        .eq('user_id', _client.auth.currentUser?.id ?? '')
        .maybeSingle();
    final orgId = meProfile?['organizacao_id'] as String?;

    final rows = await _client
        .from('permissoes')
        .select()
        .eq('role', role);
    final byKey = <String, Map<String, dynamic>>{};
    for (final row in rows) {
      final map = Map<String, dynamic>.from(row);
      final pagina = map['pagina'] as String?;
      if (pagina == null) continue;
      final cur = byKey[pagina];
      final isOrg = map['organizacao_id'] == orgId;
      if (cur == null || isOrg) byKey[pagina] = map;
    }
    return byKey.map((k, v) => MapEntry(k, PermissaoPagina.fromMap(v)));
  }
}
