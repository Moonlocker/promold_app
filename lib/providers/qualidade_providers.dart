import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/supabase/supabase_service.dart';
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

/// Anexos de um corpo de prova ou ensaio (ownerType, ownerId).
final qcAnexosProvider =
    FutureProvider.family<List<QcAnexo>, (String, String)>(
  (ref, key) => ref
      .watch(qualidadeRepositoryProvider)
      .listAnexos(ownerType: key.$1, ownerId: key.$2),
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

/// Assinatura em tempo real das tabelas de Qualidade. Ao assistir este
/// provider (basta `ref.watch(qcRealtimeProvider)`), as mudanças feitas no
/// webapp passam a invalidar os providers locais automaticamente.
final qcRealtimeProvider = Provider<void>((ref) {
  final client = SupabaseService.client;
  final channel = client.channel('qc-realtime-app');

  void invalidar(String table) {
    switch (table) {
      case 'qc_lotes_concreto':
        ref.invalidate(qcLotesProvider);
        break;
      case 'qc_corpos_prova':
        ref.invalidate(qcCpsProvider);
        ref.invalidate(qcCpsLoteProvider);
        break;
      case 'qc_ensaios':
        ref.invalidate(qcEnsaiosProvider);
        ref.invalidate(qcEnsaiosLoteProvider);
        break;
      case 'qc_anexos':
        ref.invalidate(qcAnexosProvider);
        break;
    }
  }

  for (final table in const [
    'qc_lotes_concreto',
    'qc_corpos_prova',
    'qc_ensaios',
    'qc_anexos',
  ]) {
    channel.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: table,
      callback: (_) => invalidar(table),
    );
  }
  channel.subscribe();
  ref.onDispose(() => client.removeChannel(channel));
});
