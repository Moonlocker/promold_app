import 'package:supabase_flutter/supabase_flutter.dart';

import 'organizacao.dart';
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
  });

  final User authUser;
  final String role;
  final Profile? profile;
  final Organizacao? organizacao;
  final bool isSuperAdmin;

  /// Slugs de páginas que o usuário pode acessar (RPC `user_paginas_visiveis`).
  /// Contém `*` para superadmin (acesso total).
  final Set<String> paginasVisiveis;

  String get id => authUser.id;
  String get email => authUser.email ?? '';
  String? get organizacaoId => profile?.organizacaoId;
  bool get temOrganizacao => organizacaoId != null;

  String get displayName => profile?.displayName ?? email;

  /// Mesma regra de visibilidade usada pelo `ModuleGuard` / Sidebar do webapp.
  bool podeAcessarPagina(String? pagina) {
    if (isSuperAdmin || paginasVisiveis.contains('*')) return true;
    if (pagina == null) return true;
    return paginasVisiveis.contains(pagina);
  }

  AppUser copyWith({
    String? role,
    Profile? profile,
    Organizacao? organizacao,
    bool? isSuperAdmin,
    Set<String>? paginasVisiveis,
  }) {
    return AppUser(
      authUser: authUser,
      role: role ?? this.role,
      profile: profile ?? this.profile,
      organizacao: organizacao ?? this.organizacao,
      isSuperAdmin: isSuperAdmin ?? this.isSuperAdmin,
      paginasVisiveis: paginasVisiveis ?? this.paginasVisiveis,
    );
  }
}
