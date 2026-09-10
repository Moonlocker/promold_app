import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/logic/producao_calc.dart';
import '../models/obra.dart';
import '../models/peca_catalogo.dart';
import '../models/producao_indicadores.dart';
import 'auth_providers.dart';
import 'obra_providers.dart';
import 'supabase_providers.dart';

String _iso(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// Período e filtros dos Indicadores.
class ProducaoFiltros {
  const ProducaoFiltros({
    required this.inicio,
    required this.fim,
    this.obras = const <String>{},
    this.categorias = const <String>{},
    this.pecas = const <String>{},
  });

  final DateTime inicio;
  final DateTime fim;
  final Set<String> obras;
  final Set<String> categorias;
  final Set<String> pecas;

  ProducaoFiltros copyWith({
    DateTime? inicio,
    DateTime? fim,
    Set<String>? obras,
    Set<String>? categorias,
    Set<String>? pecas,
  }) {
    return ProducaoFiltros(
      inicio: inicio ?? this.inicio,
      fim: fim ?? this.fim,
      obras: obras ?? this.obras,
      categorias: categorias ?? this.categorias,
      pecas: pecas ?? this.pecas,
    );
  }

  bool get temFiltros =>
      obras.isNotEmpty || categorias.isNotEmpty || pecas.isNotEmpty;
}

class ProducaoFiltrosNotifier extends Notifier<ProducaoFiltros> {
  @override
  ProducaoFiltros build() {
    final agora = DateTime.now();
    return ProducaoFiltros(
      inicio: DateTime(agora.year, agora.month, 1),
      fim: DateTime(agora.year, agora.month, agora.day),
    );
  }

  void setPeriodo(DateTime inicio, DateTime fim) =>
      state = state.copyWith(inicio: inicio, fim: fim);

  void setObras(Set<String> value) => state = state.copyWith(obras: value);

  /// Trocar a categoria limpa a seleção de peças (como no webapp).
  void setCategorias(Set<String> value) =>
      state = state.copyWith(categorias: value, pecas: const <String>{});

  void setPecas(Set<String> value) => state = state.copyWith(pecas: value);

  void limparFiltros() => state = state.copyWith(
    obras: const <String>{},
    categorias: const <String>{},
    pecas: const <String>{},
  );
}

final producaoFiltrosProvider =
    NotifierProvider<ProducaoFiltrosNotifier, ProducaoFiltros>(
      ProducaoFiltrosNotifier.new,
    );

/// Opções de obra para o filtro (somente obras ativas, como no webapp).
final obrasFiltroOptionsProvider = Provider<List<Obra>>((ref) {
  final obras = ref.watch(obrasListProvider).value ?? const <Obra>[];
  return obras.where((o) => o.status == 'ativa').toList();
});

/// Opções de peça, restritas às categorias selecionadas.
final pecasFiltroOptionsProvider = Provider<List<PecaCatalogo>>((ref) {
  final categorias = ref.watch(producaoFiltrosProvider).categorias;
  final pecas =
      ref.watch(pecasCatalogoProvider).value ?? const <PecaCatalogo>[];
  if (categorias.isEmpty) return pecas;
  return pecas
      .where((p) => p.categoriaId != null && categorias.contains(p.categoriaId))
      .toList();
});

/// Indicadores consolidados do período/filtros atuais.
final producaoIndicadoresProvider = FutureProvider<ProducaoIndicadores>((
  ref,
) async {
  final user = await ref.watch(appUserProvider.future);
  if (user == null) return ProducaoIndicadores.empty;

  final filtros = ref.watch(producaoFiltrosProvider);
  final inicio = _iso(filtros.inicio);
  final fim = _iso(filtros.fim);

  final repo = ref.watch(producaoRepositoryProvider);

  final registros = await repo.listProducao(inicio, fim);
  final planejamentos = await repo.listPlanejamento(inicio, fim);

  final planIds = planejamentos
      .map((p) => p.obraPecaId)
      .whereType<String>()
      .toSet()
      .toList();
  final pecasPlanejadas = await repo.listPecasPorIds(planIds);

  final catalogo = await ref.watch(pecasCatalogoProvider.future);
  final obras = await ref.watch(obrasListProvider.future);
  final todasPecas = await ref.watch(todasPecasResumoProvider.future);

  final registrosFiltrados = registros.where((r) {
    if (filtros.obras.isNotEmpty && !filtros.obras.contains(r.obraId)) {
      return false;
    }
    final catId = r.pecaCatalogo?.categoriaId;
    if (filtros.categorias.isNotEmpty &&
        (catId == null || !filtros.categorias.contains(catId))) {
      return false;
    }
    if (filtros.pecas.isNotEmpty && !filtros.pecas.contains(r.pecaCatalogoId)) {
      return false;
    }
    return true;
  }).toList();

  final chart = construirChartDiario(
    registros: registrosFiltrados,
    planejamentos: planejamentos,
    pecasPlanejadas: pecasPlanejadas,
    catalogo: catalogo,
    inicio: filtros.inicio,
    fim: filtros.fim,
  );

  final catalogoPorId = {for (final c in catalogo) c.id: c};
  final progresso = construirProgressoObras(
    obras: obras,
    pecas: todasPecas,
    obrasFiltro: filtros.obras,
    categoriasFiltro: filtros.categorias,
    pecasFiltro: filtros.pecas,
    catalogoPorId: catalogoPorId,
  );

  final soma = somarInsumos(registrosFiltrados);
  final dias = chart.where((d) => d.pecas > 0).length;
  final media = dias > 0 ? (registrosFiltrados.length / dias).round() : 0;

  return ProducaoIndicadores(
    registros: registrosFiltrados,
    chartDiario: chart,
    obrasProgresso: progresso,
    porTipo: agruparPorTipo(registrosFiltrados),
    totalPeriodo: registrosFiltrados.length,
    diasComProducao: dias,
    mediaDiaria: media,
    volumeConcreto: soma.volume,
    acoTotal: soma.aco,
  );
});
