// Testes de integração com o backend Supabase compartilhado com o webapp.
//
// Como executar (precisa de um dispositivo/emulador):
//
//   flutter test integration_test -d <device> \
//     --dart-define=TEST_EMAIL=usuario@exemplo.com \
//     --dart-define=TEST_PASSWORD=senha
//
// Opcionalmente sobrescreva o alvo Supabase:
//   --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_PUBLISHABLE_KEY=...
//
// Sem TEST_EMAIL/TEST_PASSWORD os testes são marcados como "skipped", então a
// suíte não falha por falta de credenciais.
//
// Dica: use um usuário de teste (idealmente de uma organização de testes) para
// evitar poluir dados reais. Os testes aqui são somente leitura.
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:promold_app/core/config/env.dart';
import 'package:promold_app/repositories/clientes_repository.dart';
import 'package:promold_app/repositories/configuracoes_repository.dart';
import 'package:promold_app/repositories/dashboard_repository.dart';
import 'package:promold_app/repositories/financeiro_repository.dart';
import 'package:promold_app/repositories/obras_repository.dart';
import 'package:promold_app/repositories/qualidade_repository.dart';

const _email = String.fromEnvironment('TEST_EMAIL');
const _password = String.fromEnvironment('TEST_PASSWORD');

bool get _temCredenciais => _email.isNotEmpty && _password.isNotEmpty;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await Supabase.initialize(
      url: Env.supabaseUrl,
      publishableKey: Env.supabasePublishableKey,
    );
  });

  group('Backend Promold (integração)', () {
    test('autentica com as credenciais de teste', () async {
      if (!_temCredenciais) {
        markTestSkipped('Defina TEST_EMAIL e TEST_PASSWORD via --dart-define.');
        return;
      }
      final res = await Supabase.instance.client.auth.signInWithPassword(
        email: _email,
        password: _password,
      );
      expect(res.session, isNotNull);
      expect(Supabase.instance.client.auth.currentUser, isNotNull);
    });

    test('RPC user_paginas_visiveis responde para o usuário logado', () async {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        markTestSkipped('Sem sessão (ver teste de autenticação).');
        return;
      }
      final res =
          await Supabase.instance.client.rpc('user_paginas_visiveis', params: {
        '_user_id': user.id,
      });
      expect(res, isA<List>());
    });

    test('lê os repositórios principais (somente leitura)', () async {
      if (Supabase.instance.client.auth.currentUser == null) {
        markTestSkipped('Sem sessão (ver teste de autenticação).');
        return;
      }

      final resultados = <String, int>{};

      final obras = await ObrasRepository().list();
      resultados['obras'] = obras.length;

      final clientes = await ClientesRepository().list();
      resultados['clientes'] = clientes.length;

      final contas = await FinanceiroRepository().listContas('pagar');
      resultados['contas_pagar'] = contas.length;

      final lotes = await QualidadeRepository().listLotes();
      resultados['qc_lotes'] = lotes.length;

      final config = await ConfiguracoesRepository().load();
      resultados['configuracoes'] = config.length;

      final metricas = await DashboardRepository().load();
      expect(metricas.obrasAtivas, isNonNegative);

      // Nenhuma exceção de rede/RLS deve ter ocorrido nas leituras acima.
      expect(resultados.length, 5);
    });

    test('faz logout ao final', () async {
      if (Supabase.instance.client.auth.currentUser == null) {
        markTestSkipped('Sem sessão.');
        return;
      }
      await Supabase.instance.client.auth.signOut();
      expect(Supabase.instance.client.auth.currentUser, isNull);
    });
  });
}
