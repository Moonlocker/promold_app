import 'package:supabase_flutter/supabase_flutter.dart';

/// Ponto único de acesso ao backend Supabase compartilhado com o webapp.
///
/// Não cria banco, autenticação ou regras próprias: apenas encapsula o client
/// já inicializado em [Supabase.instance]. Toda segurança (RLS) é a mesma do
/// sistema web, pois é o mesmo projeto Supabase.
class SupabaseService {
  SupabaseService._();

  static SupabaseClient get client => Supabase.instance.client;

  static GoTrueClient get auth => client.auth;

  static User? get currentUser => auth.currentUser;

  static Session? get currentSession => auth.currentSession;

  /// Chama uma função RPC do Postgres (mesmas funções usadas pelo webapp).
  static Future<dynamic> rpc(
    String fn, {
    Map<String, dynamic>? params,
  }) {
    return client.rpc(fn, params: params);
  }

  /// Invoca uma Edge Function do Supabase (mesmas functions do webapp).
  static Future<FunctionResponse> invoke(
    String fn, {
    Map<String, dynamic>? body,
  }) {
    return client.functions.invoke(fn, body: body);
  }
}
