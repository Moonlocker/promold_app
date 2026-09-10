import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/supabase/supabase_service.dart';
import '../models/app_user.dart';
import '../models/organizacao.dart';
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

    return AppUser(
      authUser: authUser,
      role: role,
      profile: profile,
      organizacao: organizacao,
      isSuperAdmin: isSuperAdmin,
      paginasVisiveis: paginas,
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
}
