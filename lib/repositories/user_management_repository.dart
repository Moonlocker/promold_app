import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/supabase/supabase_service.dart';
import '../models/permissoes.dart';

/// Gestão de usuários, perfis de acesso e permissões.
class UserManagementRepository {
  UserManagementRepository({SupabaseClient? client})
      : _client = client ?? SupabaseService.client;

  final SupabaseClient _client;

  // ------------------------------------------------------------- Usuários
  Future<List<Map<String, dynamic>>> listUsuarios() async {
    final user = _client.auth.currentUser;
    if (user == null) return [];
    final meRole = await _client
        .from('user_roles')
        .select('role')
        .eq('user_id', user.id)
        .maybeSingle();
    final meProfile = await _client
        .from('profiles')
        .select('organizacao_id')
        .eq('user_id', user.id)
        .maybeSingle();
    final isSuper = (meRole?['role'] as String?) == 'superadmin';
    final orgId = meProfile?['organizacao_id'] as String?;

    var query = _client.from('profiles').select('*');
    if (!isSuper && orgId != null) {
      query = query.eq('organizacao_id', orgId);
    }
    final profiles = await query.order('nome');
    final roles = await _client.from('user_roles').select('user_id, role');
    final roleMap = {
      for (final r in roles) r['user_id'] as String: r['role'] as String,
    };
    return profiles
        .map((p) => {
              ...Map<String, dynamic>.from(p),
              'role': roleMap[p['user_id']],
            })
        .toList();
  }

  Future<void> updateUserRole(String userId, String role) async {
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
      await _client.from('user_roles').insert({'user_id': userId, 'role': role});
    }
  }

  /// Cria usuário via edge function `create-user`.
  Future<void> createUser({
    required String email,
    required String password,
    required String nome,
    required String role,
    String? organizacaoId,
  }) async {
    final res = await _client.functions.invoke('create-user', body: {
      'email': email,
      'password': password,
      'nome': nome,
      'role': role,
      'organizacao_id': ?organizacaoId,
    });
    final data = res.data;
    if (data is Map && data['error'] != null) {
      throw Exception(data['error']);
    }
  }

  // -------------------------------------------------------- Perfis de acesso
  Future<List<PerfilAcesso>> listPerfis() async {
    final rows = await _client
        .from('perfis_acesso')
        .select()
        .eq('ativo', true)
        .order('nome');
    return rows
        .map((e) => PerfilAcesso.fromMap(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<PerfilAcesso> createPerfil({
    required String nome,
    required String slug,
    String? descricao,
  }) async {
    final row = await _client
        .from('perfis_acesso')
        .insert({'nome': nome, 'slug': slug, 'descricao': descricao})
        .select()
        .single();
    // Cria permissões zeradas para todas as páginas.
    await _client.from('permissoes').insert(
          allPages
              .map((p) => {
                    'role': slug,
                    'pagina': p,
                    'pode_visualizar': false,
                    'pode_criar': false,
                    'pode_editar': false,
                    'pode_excluir': false,
                  })
              .toList(),
        );
    return PerfilAcesso.fromMap(Map<String, dynamic>.from(row));
  }

  Future<void> deletePerfil(PerfilAcesso perfil) async {
    await _client.from('permissoes').delete().eq('role', perfil.slug);
    await _client.from('perfis_acesso').delete().eq('id', perfil.id);
  }

  // -------------------------------------------------------------- Permissões
  Future<List<Permissao>> listPermissoes() async {
    final user = _client.auth.currentUser;
    final meProfile = user == null
        ? null
        : await _client
            .from('profiles')
            .select('organizacao_id')
            .eq('user_id', user.id)
            .maybeSingle();
    final orgId = meProfile?['organizacao_id'] as String?;

    final rows = await _client
        .from('permissoes')
        .select()
        .order('role')
        .order('pagina');
    final all = rows
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    if (orgId == null) {
      return all.map(Permissao.fromMap).toList();
    }
    // Prefere linhas da organização; mantém globais quando não sobrescritas.
    final byKey = <String, Map<String, dynamic>>{};
    for (final p in all) {
      final key = '${p['role']}::${p['pagina']}';
      final cur = byKey[key];
      final isOrg = p['organizacao_id'] == orgId;
      if (cur == null || isOrg) byKey[key] = p;
    }
    return byKey.values.map(Permissao.fromMap).toList();
  }

  Future<void> updatePermissao(
    String id,
    String campo,
    bool value,
  ) async {
    await _client.from('permissoes').update({campo: value}).eq('id', id);
  }
}
