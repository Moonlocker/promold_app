import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/config/env.dart';
import 'core/offline/connectivity.dart';
import 'core/offline/offline_database.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Mesmo projeto Supabase do sistema web Promold.
  await Supabase.initialize(
    url: Env.supabaseUrl,
    publishableKey: Env.supabasePublishableKey,
  );

  // Infraestrutura offline: banco local (cache + fila) e monitor de conexão.
  await OfflineDatabase.instance.init();
  await AppConnectivity.instance.start();

  runApp(const ProviderScope(child: PromoldApp()));
}
