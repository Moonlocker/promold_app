// Smoke test de UI: garante que o app inicializa sem exceções e monta o
// MaterialApp/Router. Não depende de credenciais.
//
//   flutter test integration_test -d <device>
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:promold_app/app.dart';
import 'package:promold_app/core/config/env.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await Supabase.initialize(
      url: Env.supabaseUrl,
      publishableKey: Env.supabasePublishableKey,
    );
  });

  testWidgets('o app monta o MaterialApp e a rota inicial sem erros',
      (tester) async {
    await tester.pumpWidget(const ProviderScope(child: PromoldApp()));
    // Deixa o router resolver a rota inicial (splash → login/dashboard).
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump(const Duration(seconds: 1));

    expect(find.byType(MaterialApp), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
