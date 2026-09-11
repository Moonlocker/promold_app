import 'package:supabase_flutter/supabase_flutter.dart';

import 'organizacao.dart';
import 'permissoes.dart';
import 'profile.dart';

/// Usuário autenticado já enriquecido com perfil, organização, papel e
/// permissões de páginas — o mesmo conjunto de dados que o webapp resolve
/// via `profiles`, `user_roles` e RPC `user_paginas_visiveis`.
class AppUser {
  const AppUser({
    required this.authUser,
    required this.role,
    this.profile,
    this.organizacao,
    this.isSuperAdmin = false,
    this.paginasVisiveis = const <String>{},
    this.permissoes = const <String, PermissaoPagina>{},
  });

  final User authUser;
  final String role;
  final Profile? profile;
  final Organizacao? organizacao;
  final bool isSuperAdmin;

  /// Slugs de páginas que o usuário pode acessar (RPC `user_paginas_visiveis`).
  /// Contém `*` para superadmin (acesso total).
  final Set<String> paginasVisiveis;

  /// Direitos granulares por página (tabela `permissoes` do papel do usuário).
  final Map<String, PermissaoPagina> permissoes;

  String get id => authUser.id;
  String get email => authUser.email ?? '';
  String? get organizacaoId => profile?.organizacaoId;
  bool get temOrganizacao => organizacaoId != null;

  String get displayName => profile?.displayName ?? email;

  bool get isAdmin => role == 'admin' || isSuperAdmin;

  /// Organização criada mas desativada/bloqueada (mesma regra do webapp).
  bool get organizacaoInativa {
    final org = organizacao;
    if (org == null || isSuperAdmin) return false;
    return org.ativo == false || org.bloqueioTipo != null;
  }

  /// Mesma regra de visibilidade usada pelo `ModuleGuard` / Sidebar do webapp.
  bool podeAcessarPagina(String? pagina) {
    if (isSuperAdmin || paginasVisiveis.contains('*')) return true;
    if (pagina == null) return true;
    return paginasVisiveis.contains(pagina);
  }

  PermissaoPagina _perm(String? pagina) {
    if (pagina == null) return const PermissaoPagina();
    return permissoes[pagina] ?? const PermissaoPagina();
  }

  bool podeCriar(String? pagina) =>
      isAdmin || _perm(pagina).podeCriar;

  bool podeEditar(String? pagina) =>
      isAdmin || _perm(pagina).podeEditar;

  bool podeExcluir(String? pagina) =>
      isAdmin || _perm(pagina).podeExcluir;

  AppUser copyWith({
    String? role,
    Profile? profile,
    Organizacao? organizacao,
    bool? isSuperAdmin,
    Set<String>? paginasVisiveis,
    Map<String, PermissaoPagina>? permissoes,
  }) {
    return AppUser(
      authUser: authUser,
      role: role ?? this.role,
      profile: profile ?? this.profile,
      organizacao: organizacao ?? this.organizacao,
      isSuperAdmin: isSuperAdmin ?? this.isSuperAdmin,
      paginasVisiveis: paginasVisiveis ?? this.paginasVisiveis,
      permissoes: permissoes ?? this.permissoes,
    );
  }
}
