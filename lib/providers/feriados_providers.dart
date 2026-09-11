import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/feriado.dart';
import 'supabase_providers.dart';

/// Feriados da organização.
final feriadosProvider = FutureProvider<List<Feriado>>(
  (ref) => ref.watch(feriadosRepositoryProvider).list(),
);
