import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/estoque.dart';
import 'supabase_providers.dart';

/// Estoques (locais de armazenamento) da organização.
final estoquesProvider = FutureProvider<List<Estoque>>(
  (ref) => ref.watch(estoqueRepositoryProvider).listEstoques(),
);

/// Peças com `status = 'em_estoque'`.
final pecasEmEstoqueProvider = FutureProvider<List<PecaEmEstoque>>(
  (ref) => ref.watch(estoqueRepositoryProvider).listPecasEmEstoque(),
);

/// Id do estoque "sistema" que hospeda o mapa visual.
final systemEstoqueIdProvider = FutureProvider<String>(
  (ref) => ref.watch(estoqueRepositoryProvider).getSystemEstoqueId(),
);

final estoqueConfigProvider =
    FutureProvider.family<EstoqueVisualConfig?, String>(
  (ref, estoqueId) =>
      ref.watch(estoqueRepositoryProvider).getConfig(estoqueId),
);

final estoqueElementosProvider =
    FutureProvider.family<List<EstoqueVisualElemento>, String>(
  (ref, estoqueId) =>
      ref.watch(estoqueRepositoryProvider).listElementos(estoqueId),
);
