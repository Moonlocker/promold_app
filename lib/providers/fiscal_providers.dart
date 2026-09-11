import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/nota_fiscal.dart';
import 'supabase_providers.dart';

/// Notas fiscais emitidas.
final notasFiscaisProvider = FutureProvider<List<NotaFiscal>>(
  (ref) => ref.watch(fiscalRepositoryProvider).listNotas(),
);

/// Itens de uma nota fiscal.
final notasFiscaisItensProvider =
    FutureProvider.family<List<NotaFiscalItem>, String>(
  (ref, notaId) => ref.watch(fiscalRepositoryProvider).listItens(notaId),
);

/// Notas fiscais recebidas.
final notasRecebidasProvider = FutureProvider<List<NotaFiscalRecebida>>(
  (ref) => ref.watch(fiscalRepositoryProvider).listRecebidas(),
);

/// Configuração fiscal da organização.
final fiscalConfigProvider = FutureProvider<Map<String, dynamic>?>(
  (ref) => ref.watch(fiscalRepositoryProvider).getConfig(),
);
