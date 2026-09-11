import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/permissoes.dart';
import 'supabase_providers.dart';

/// Usuários da organização com o papel (role).
final usuariosComRoleProvider = FutureProvider<List<Map<String, dynamic>>>(
  (ref) => ref.watch(userManagementRepositoryProvider).listUsuarios(),
);

/// Perfis de acesso da organização.
final perfisAcessoProvider = FutureProvider<List<PerfilAcesso>>(
  (ref) => ref.watch(userManagementRepositoryProvider).listPerfis(),
);

/// Permissões por perfil.
final permissoesProvider = FutureProvider<List<Permissao>>(
  (ref) => ref.watch(userManagementRepositoryProvider).listPermissoes(),
);
