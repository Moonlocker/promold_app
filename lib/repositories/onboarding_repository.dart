import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/supabase/supabase_service.dart';
import '../models/modulo_comercial.dart';

/// Onboarding: criação de conta e organização (mesmo fluxo do webapp).
class OnboardingRepository {
  OnboardingRepository({SupabaseClient? client})
      : _client = client ?? SupabaseService.client;

  final SupabaseClient _client;

  Future<List<ModuloComercial>> listModulos() async {
    final rows = await _client
        .from('modulos')
        .select('id, slug, nome, descricao, cor, valor_mensal, preco_por_m3, ativo, core')
        .eq('ativo', true)
        .order('nome');
    return rows
        .map((e) => ModuloComercial.fromMap(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// Cria a conta de acesso. Retorna `true` se já houver sessão ativa
  /// (confirmação de e-mail desativada).
  Future<bool> signUp({
    required String email,
    required String password,
    required String nome,
  }) async {
    await _client.auth.signUp(
      email: email,
      password: password,
      data: {'nome': nome},
    );
    try {
      final res = await _client.auth
          .signInWithPassword(email: email, password: password);
      return res.session != null;
    } on AuthException {
      return false;
    }
  }

  /// Cria a organização e vincula o usuário. Retorna o id da organização.
  Future<String> criarOrganizacao({
    required String nome,
    String? cnpj,
    required List<String> moduloIds,
    double? m3,
  }) async {
    final result = await _client.rpc(
      'criar_organizacao_onboarding_modulos',
      params: {
        '_nome': nome,
        '_cnpj': cnpj ?? '',
        '_modulo_ids': moduloIds,
        '_m3': m3 ?? 0,
      },
    );
    return result?.toString() ?? '';
  }
}
