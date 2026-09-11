import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/categoria_peca.dart';
import '../models/peca_catalogo.dart';
import 'supabase_providers.dart';

/// Peças do catálogo (com categoria embutida).
final pecasCatalogoListProvider = FutureProvider<List<PecaCatalogo>>(
  (ref) => ref.watch(pecasCatalogoRepositoryProvider).list(),
);

/// Categorias de peça.
final categoriasPecaListProvider = FutureProvider<List<CategoriaPeca>>(
  (ref) => ref.watch(pecasCatalogoRepositoryProvider).listCategorias(),
);
