import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/supabase/supabase_service.dart';

/// Ações de autenticação. Reutiliza o Supabase Auth do webapp: os mesmos
/// usuários, senhas e sessões (GoTrue).
class AuthService {
  AuthService({SupabaseClient? client})
      : _client = client ?? SupabaseService.client;

  final SupabaseClient _client;

  GoTrueClient get _auth => _client.auth;

  User? get currentUser => _auth.currentUser;

  /// Sessão atual + mudanças de autenticação.
  ///
  /// `onAuthStateChange` é um ReplaySubject no SDK, então já entrega o evento
  /// inicial (`initialSession`) — inclusive o caso "sem sessão". Isso evita
  /// exibir a tela de login antes de a sessão persistida ser restaurada.
  Stream<Session?> sessionStream() =>
      _auth.onAuthStateChange.map((state) => state.session);

  Future<void> signIn({required String email, required String password}) async {
    final response = await _auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
    if (response.session == null) {
      throw const AuthException('Não foi possível iniciar a sessão.');
    }
  }

  Future<void> signOut() => _auth.signOut();

  Future<void> sendPasswordReset(String email) =>
      _auth.resetPasswordForEmail(email.trim());
}
