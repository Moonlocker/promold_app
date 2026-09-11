import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/qc.dart';
import 'supabase_providers.dart';

/// Todos os lotes de concreto.
final qcLotesProvider = FutureProvider<List<QcLote>>(
  (ref) => ref.watch(qualidadeRepositoryProvider).listLotes(),
);

/// Todos os corpos de prova.
final qcCpsProvider = FutureProvider<List<QcCorpoProva>>(
  (ref) => ref.watch(qualidadeRepositoryProvider).listCps(),
);

/// Todos os ensaios.
final qcEnsaiosProvider = FutureProvider<List<QcEnsaio>>(
  (ref) => ref.watch(qualidadeRepositoryProvider).listEnsaios(),
);

/// Corpos de prova de um lote.
final qcCpsLoteProvider = FutureProvider.family<List<QcCorpoProva>, String>(
  (ref, loteId) => ref.watch(qualidadeRepositoryProvider).listCps(loteId: loteId),
);

/// Ensaios de um lote.
final qcEnsaiosLoteProvider = FutureProvider.family<List<QcEnsaio>, String>(
  (ref, loteId) =>
      ref.watch(qualidadeRepositoryProvider).listEnsaios(loteId: loteId),
);

/// Padrões de código.
final qcPadroesProvider = FutureProvider<List<QcPadrao>>(
  (ref) => ref.watch(qualidadeRepositoryProvider).listPadroes(),
);

/// Busca de peças de obra por identificador (rastreabilidade).
final qcBuscarPecasProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>(
  (ref, termo) => ref.watch(qualidadeRepositoryProvider).buscarPecas(termo),
);

/// Peças de obra vinculadas a um lote.
final qcPecasPorLoteProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>(
  (ref, loteId) => ref.watch(qualidadeRepositoryProvider).pecasPorLote(loteId),
);
