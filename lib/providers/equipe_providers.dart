import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/ausencia.dart';
import '../models/cargo.dart';
import '../models/funcionario.dart';
import '../models/setor.dart';
import 'supabase_providers.dart';

/// Funcionários da organização (com cargo e setor).
final funcionariosListProvider = FutureProvider<List<Funcionario>>(
  (ref) => ref.watch(equipeRepositoryProvider).listFuncionarios(),
);

/// Setores da organização.
final setoresListProvider = FutureProvider<List<Setor>>(
  (ref) => ref.watch(equipeRepositoryProvider).listSetores(),
);

/// Cargos da organização (com setor).
final cargosListProvider = FutureProvider<List<Cargo>>(
  (ref) => ref.watch(equipeRepositoryProvider).listCargos(),
);

/// Todas as ausências da organização.
final ausenciasListProvider = FutureProvider<List<Ausencia>>(
  (ref) => ref.watch(equipeRepositoryProvider).listAusencias(),
);

/// Ausências de um funcionário específico.
final ausenciasFuncionarioProvider =
    FutureProvider.family<List<Ausencia>, String>(
  (ref, funcionarioId) =>
      ref.watch(equipeRepositoryProvider).listAusenciasByFuncionario(funcionarioId),
);
