import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/logic/status_config.dart';
import '../models/categoria_peca.dart';
import '../models/obra.dart';
import '../models/obra_historico.dart';
import '../models/obra_ifc.dart';
import '../models/obra_midia.dart';
import '../models/mapa_montagem.dart';
import '../models/obra_peca.dart';
import '../models/peca_catalogo.dart';
import '../models/processo_etapa.dart';
import 'supabase_providers.dart';

/// Cores e pesos de status configuráveis por organização.
class StatusConfig {
  const StatusConfig({required this.colors, required this.weights});

  final Map<String, Color> colors;
  final Map<String, double> weights;

  static const defaults = StatusConfig(
    colors: defaultStatusColors,
    weights: defaultStatusWeights,
  );

  Color colorOf(String? status) => statusColor(status, colors);
  double weightOf(String? status) => statusWeight(status, weights);
}

final statusConfigProvider = FutureProvider<StatusConfig>((ref) async {
  final cfg = await ref.watch(configuracoesRepositoryProvider).load();
  final colors = Map<String, Color>.from(defaultStatusColors);
  final weights = Map<String, double>.from(defaultStatusWeights);

  statusColorConfigKeys.forEach((status, key) {
    final color = hexToColor(cfg[key]);
    if (color != null) colors[status] = color;
  });
  statusWeightConfigKeys.forEach((status, key) {
    final raw = cfg[key];
    if (raw == null || raw.isEmpty) return;
    final n = double.tryParse(raw.replaceAll(',', '.'));
    if (n != null) weights[status] = n.clamp(0, 100);
  });

  return StatusConfig(colors: colors, weights: weights);
});

// ------------------------------------------------------------------- Obras
final obraProvider = FutureProvider.family<Obra?, String>((ref, id) {
  return ref.watch(obrasRepositoryProvider).getById(id);
});

final obrasPecasProvider = FutureProvider.family<List<ObraPeca>, String>(
  (ref, obraId) => ref.watch(obrasRepositoryProvider).listPecas(obraId),
);

/// Posição de cada peça no mapa de montagem (para etiquetas).
final obraPosicoesProvider = FutureProvider.family<Map<String, String>, String>(
  (ref, obraId) => ref.watch(obrasRepositoryProvider).listPosicoes(obraId),
);

final pecasCatalogoProvider = FutureProvider<List<PecaCatalogo>>(
  (ref) => ref.watch(obrasRepositoryProvider).listPecasCatalogo(),
);

/// Resumo (obra + status) de todas as peças, para o progresso na listagem.
final todasPecasResumoProvider = FutureProvider<List<ObraPeca>>(
  (ref) => ref.watch(obrasRepositoryProvider).listPecasResumo(),
);

final categoriasPecaProvider = FutureProvider<List<CategoriaPeca>>(
  (ref) => ref.watch(obrasRepositoryProvider).listCategoriasPeca(),
);

// -------------------------------------------------------------- Fotos/Anexos
final obraFotosProvider = FutureProvider.family<List<ObraFoto>, String>(
  (ref, obraId) => ref.watch(obraMidiaRepositoryProvider).listFotos(obraId),
);

final obraAnexosProvider = FutureProvider.family<List<ObraAnexo>, String>(
  (ref, obraId) => ref.watch(obraMidiaRepositoryProvider).listAnexos(obraId),
);

// ---------------------------------------------------------------- Histórico
final obraHistoricoProvider = FutureProvider.family<List<ObraHistorico>, String>(
  (ref, obraId) => ref.watch(obraHistoricoRepositoryProvider).listMerged(obraId),
);

final obraMonitoramentoProvider =
    FutureProvider.family<ObraMonitoramento?, String>((ref, obraId) async {
  final user = ref.watch(authServiceProvider).currentUser;
  if (user == null) return null;
  return ref
      .watch(obraHistoricoRepositoryProvider)
      .getMonitoramento(obraId, user.id);
});

// ------------------------------------------------------------------ Insumos
final obraInsumosProvider = FutureProvider.family<List<ObraInsumo>, String>(
  (ref, obraId) => ref.watch(obraInsumosRepositoryProvider).list(obraId),
);

// ---------------------------------------------------------------- Processos
final processosEtapasProvider = FutureProvider<List<ProcessoEtapa>>(
  (ref) => ref.watch(processosRepositoryProvider).listProcessos(),
);

final processosEtapasItensProvider = FutureProvider<List<ProcessoEtapaItem>>(
  (ref) => ref.watch(processosRepositoryProvider).listItens(),
);

// ------------------------------------------------------------------- IFC 3D
final obraIfcArquivosProvider =
    FutureProvider.family<List<ObraIfcArquivo>, String>(
  (ref, obraId) => ref.watch(obraIfcRepositoryProvider).listByObra(obraId),
);

// ------------------------------------------------------ Mapa de Montagem 2D
final obraMapaVistasProvider =
    FutureProvider.family<List<MapaMontagemVista>, String>(
  (ref, obraId) => ref.watch(mapaMontagemRepositoryProvider).listVistas(obraId),
);

final obraMapaCelulasProvider =
    FutureProvider.family<List<MapaMontagemCelula>, String>(
  (ref, vistaId) => ref.watch(mapaMontagemRepositoryProvider).listCelulas(vistaId),
);

final obraEtapaStatusProvider = FutureProvider<List<ObraEtapaStatus>>(
  (ref) => ref.watch(processosRepositoryProvider).listStatus(),
);

/// Filtro de status aplicado na aba Peças (definido pela Visão Geral).
class ObraPecasFilter extends Notifier<String?> {
  @override
  String? build() => null;

  void set(String? value) => state = value;
}

final obraPecasFilterProvider =
    NotifierProvider<ObraPecasFilter, String?>(ObraPecasFilter.new);
