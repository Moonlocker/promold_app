import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/capacidade.dart';
import 'supabase_providers.dart';

/// Áreas produtivas.
final areasProdutivasProvider = FutureProvider<List<AreaProdutiva>>(
  (ref) => ref.watch(capacidadeRepositoryProvider).listAreas(),
);

/// Capacidades cadastradas.
final capacidadesFabricaProvider = FutureProvider<List<CapacidadeFabrica>>(
  (ref) => ref.watch(capacidadeRepositoryProvider).listCapacidades(),
);
