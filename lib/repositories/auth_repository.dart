import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/offline/offline_database.dart';
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
    try {
      final user = await _buildAppUser(authUser);
      await _cacheUser(user);
      return user;
    } catch (_) {
      // Offline: reaproveita o último perfil carregado (a sessão já é
      // persistida localmente pelo Supabase).
      final cached = await _loadCachedUser(authUser);
      if (cached != null) return cached;
      rethrow;
    }
  }

  Future<AppUser> _buildAppUser(User authUser) async {
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

  String _cacheKey(String userId) => 'auth:appuser:$userId';

  Future<void> _cacheUser(AppUser user) async {
    await OfflineDatabase.instance.writeCache(_cacheKey(user.id), {
      'role': user.role,
      'profile': user.profile?.toMap(),
      'organizacao': user.organizacao?.toMap(),
      'isSuperAdmin': user.isSuperAdmin,
      'paginas': user.paginasVisiveis.toList(),
      'permissoes': user.permissoes.map((k, v) => MapEntry(k, v.toMap())),
    });
  }

  Future<AppUser?> _loadCachedUser(User authUser) async {
    final cached = await OfflineDatabase.instance.readCache(_cacheKey(authUser.id));
    if (cached is! Map) return null;
    final map = Map<String, dynamic>.from(cached);
    final permsRaw = map['permissoes'];
    final permissoes = <String, PermissaoPagina>{};
    if (permsRaw is Map) {
      permsRaw.forEach((key, value) {
        if (value is Map) {
          permissoes[key.toString()] =
              PermissaoPagina.fromMap(Map<String, dynamic>.from(value));
        }
      });
    }
    return AppUser(
      authUser: authUser,
      role: (map['role'] as String?) ?? 'visualizador',
      profile: map['profile'] is Map
          ? Profile.fromMap(Map<String, dynamic>.from(map['profile'] as Map))
          : null,
      organizacao: map['organizacao'] is Map
          ? Organizacao.fromMap(
              Map<String, dynamic>.from(map['organizacao'] as Map))
          : null,
      isSuperAdmin: (map['isSuperAdmin'] as bool?) ?? false,
      paginasVisiveis:
          ((map['paginas'] as List?) ?? const []).whereType<String>().toSet(),
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
