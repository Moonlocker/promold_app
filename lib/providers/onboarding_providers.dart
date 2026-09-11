import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/modulo_comercial.dart';
import 'supabase_providers.dart';

/// Módulos comerciáveis disponíveis (para onboarding).
final modulosComerciaisProvider = FutureProvider<List<ModuloComercial>>(
  (ref) => ref.watch(onboardingRepositoryProvider).listModulos(),
);
