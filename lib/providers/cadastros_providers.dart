import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/categoria_financeira.dart';
import '../models/centro_custo.dart';
import '../models/cliente.dart';
import '../models/fornecedor.dart';
import 'supabase_providers.dart';

/// Clientes da organização.
final clientesListProvider = FutureProvider<List<Cliente>>(
  (ref) => ref.watch(clientesRepositoryProvider).list(),
);

/// Fornecedores da organização.
final fornecedoresListProvider = FutureProvider<List<Fornecedor>>(
  (ref) => ref.watch(fornecedoresRepositoryProvider).list(),
);

/// Centros de custo.
final centrosCustoListProvider = FutureProvider<List<CentroCusto>>(
  (ref) => ref.watch(financeiroCadastrosRepositoryProvider).listCentros(),
);

/// Categorias financeiras.
final categoriasFinanceirasListProvider =
    FutureProvider<List<CategoriaFinanceira>>(
  (ref) => ref.watch(financeiroCadastrosRepositoryProvider).listCategorias(),
);
