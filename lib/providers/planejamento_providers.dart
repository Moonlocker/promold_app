import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/logic/painel_calc.dart';
import '../core/utils/formatters.dart';
import '../models/planejamento.dart';
import 'auth_providers.dart';
import 'obra_providers.dart';
import 'supabase_providers.dart';

const List<String> _diasAbrev = [
  'dom',
  'seg',
  'ter',
  'qua',
  'qui',
  'sex',
  'sáb',
];

/// Aba atual: `armacao`, `producao` ou `montagem`.
class PlanejamentoTipoNotifier extends Notifier<String> {
  @override
  String build() => 'armacao';

  void set(String value) => state = value;
}

final planejamentoTipoProvider =
    NotifierProvider<PlanejamentoTipoNotifier, String>(
      PlanejamentoTipoNotifier.new,
    );

/// Semana selecionada (normalizada para o domingo).
class PlanejamentoSemanaNotifier extends Notifier<DateTime> {
  @override
  DateTime build() => inicioDaSemana(DateTime.now());

  void anterior() => state = state.subtract(const Duration(days: 7));
  void proxima() => state = state.add(const Duration(days: 7));
  void irPara(DateTime d) => state = inicioDaSemana(d);
}

final planejamentoSemanaProvider =
    NotifierProvider<PlanejamentoSemanaNotifier, DateTime>(
      PlanejamentoSemanaNotifier.new,
    );

/// Dia selecionado na semana.
class PlanejamentoDiaNotifier extends Notifier<DateTime> {
  @override
  DateTime build() {
    final agora = DateTime.now();
    return DateTime(agora.year, agora.month, agora.day);
  }

  void set(DateTime dia) => state = dia;
}

final planejamentoDiaProvider =
    NotifierProvider<PlanejamentoDiaNotifier, DateTime>(
      PlanejamentoDiaNotifier.new,
    );

/// Dados de armação/produção da semana selecionada.
final planejamentoDadosProvider = FutureProvider<PlanejamentoDados>((
  ref,
) async {
  final user = await ref.watch(appUserProvider.future);
  if (user == null) return PlanejamentoDados.empty;

  final tipo = ref.watch(planejamentoTipoProvider);
  if (tipo == 'montagem') return PlanejamentoDados.empty;
  final isArmacao = tipo == 'armacao';

  final semana = ref.watch(planejamentoSemanaProvider);
  final fim = semana.add(const Duration(days: 6));
  final repo = ref.watch(producaoRepositoryProvider);

  final planejamentos = await repo.listPlanejamento(
    Formatters.iso(semana),
    Formatters.iso(fim),
    tipo: tipo,
  );

  final planIds = planejamentos
      .map((p) => p.obraPecaId)
      .whereType<String>()
      .toSet()
      .toList();
  final pecas = await repo.listPecasPorIds(planIds);
  final pecasPorId = {for (final p in pecas) p.id: p};

  final obras = await ref.watch(obrasListProvider.future);
  final obrasPorId = {for (final o in obras) o.id: o};
  final catalogo = await ref.watch(pecasCatalogoProvider.future);
  final catalogoPorId = {for (final c in catalogo) c.id: c};

  final dias = <PlanejamentoDia>[];
  for (var i = 0; i < 7; i++) {
    final dia = semana.add(Duration(days: i));
    final diaStr = Formatters.iso(dia);
    var total = 0;
    var concluidos = 0;
    for (final p in planejamentos) {
      if (p.dataInicio.compareTo(diaStr) <= 0 &&
          p.dataFim.compareTo(diaStr) >= 0) {
        total++;
        final piece = p.obraPecaId != null ? pecasPorId[p.obraPecaId] : null;
        if (isRealizadoStatus(piece?.status, isArmacao)) concluidos++;
      }
    }
    dias.add(
      PlanejamentoDia(
        dia: dia,
        diaStr: diaStr,
        diaNome: _diasAbrev[dia.weekday % 7],
        total: total,
        concluidos: concluidos,
      ),
    );
  }

  final selecionado = ref.watch(planejamentoDiaProvider);
  final selStr = Formatters.iso(selecionado);
  final itens = <PlanejamentoItem>[];
  for (final p in planejamentos) {
    if (p.dataInicio.compareTo(selStr) > 0 || p.dataFim.compareTo(selStr) < 0) {
      continue;
    }
    final piece = p.obraPecaId != null ? pecasPorId[p.obraPecaId] : null;
    final peca = p.pecaCatalogoId != null
        ? catalogoPorId[p.pecaCatalogoId]
        : null;
    final obra = p.obraId != null ? obrasPorId[p.obraId] : null;
    itens.add(
      PlanejamentoItem(
        planId: p.id,
        obraId: p.obraId ?? '',
        obraNome: obra?.nome ?? 'Obra',
        obraCor: obra?.cor,
        obraPecaId: p.obraPecaId,
        pecaNome: peca?.nome ?? piece?.pecaCatalogo?.nome ?? 'Peça',
        identificador: piece?.identificador.isNotEmpty == true
            ? piece!.identificador
            : (p.obraPecaId != null
                  ? '#${p.obraPecaId!.substring(0, 8)}'
                  : 'Sem ID'),
        status: piece?.status ?? 'pendente',
        concluido: isRealizadoStatus(piece?.status, isArmacao),
      ),
    );
  }

  return PlanejamentoDados(dias: dias, itensDoDia: itens);
});

/// Planejamento de montagem da semana selecionada.
final planejamentoMontagemProvider = FutureProvider<List<PlanejamentoMontagem>>(
  (ref) async {
    final user = await ref.watch(appUserProvider.future);
    if (user == null) return const <PlanejamentoMontagem>[];

    final semana = ref.watch(planejamentoSemanaProvider);
    final fim = semana.add(const Duration(days: 6));
    final rows = await ref
        .watch(producaoRepositoryProvider)
        .listMontagem(Formatters.iso(semana), Formatters.iso(fim));
    return rows.map(PlanejamentoMontagem.fromMap).toList();
  },
);

/// IDs de peças já planejadas num dia/tipo (para evitar duplicidade).
final planejamentoDiaExistenteProvider =
    FutureProvider.family<Set<String>, (String, String)>((ref, arg) async {
      final rows = await ref
          .watch(producaoRepositoryProvider)
          .listPlanejamentoDia(arg.$1, arg.$2);
      return rows.map((p) => p.obraPecaId).whereType<String>().toSet();
    });

/// Item de planejamento focado em uma obra.
class ObraPlanoItem {
  const ObraPlanoItem({
    required this.planId,
    required this.dataInicio,
    required this.dataFim,
    required this.identificador,
    required this.pecaNome,
    required this.status,
    this.obraPecaId,
    this.observacoes,
    this.montagem = false,
  });

  final String planId;
  final String dataInicio;
  final String dataFim;
  final String identificador;
  final String pecaNome;
  final String status;
  final String? obraPecaId;
  final String? observacoes;
  final bool montagem;
}

/// Planejamento (armação/produção/montagem) filtrado por obra e semana.
final obraPlanoProvider = FutureProvider.family<List<ObraPlanoItem>,
    (String, String, DateTime)>((ref, arg) async {
  final (obraId, tipo, semana) = arg;
  final fim = semana.add(const Duration(days: 6));
  final repo = ref.watch(producaoRepositoryProvider);
  final itens = <ObraPlanoItem>[];

  if (tipo == 'montagem') {
    final rows = await repo.listMontagem(
      Formatters.iso(semana),
      Formatters.iso(fim),
    );
    for (final m in rows.map(PlanejamentoMontagem.fromMap)) {
      if (m.obraId != obraId) continue;
      itens.add(ObraPlanoItem(
        planId: m.id,
        dataInicio: m.dataInicio,
        dataFim: m.dataFim,
        identificador: 'Montagem',
        pecaNome: 'Montagem da obra',
        status: 'pendente',
        observacoes: m.observacoes,
        montagem: true,
      ));
    }
    return itens;
  }

  final rows = await repo.listPlanejamento(
    Formatters.iso(semana),
    Formatters.iso(fim),
    tipo: tipo,
  );
  final pecas = await ref.watch(obrasPecasProvider(obraId).future);
  final pecasPorId = {for (final p in pecas) p.id: p};
  for (final p in rows.where((p) => p.obraId == obraId)) {
    final piece = p.obraPecaId != null ? pecasPorId[p.obraPecaId] : null;
    itens.add(ObraPlanoItem(
      planId: p.id,
      dataInicio: p.dataInicio,
      dataFim: p.dataFim,
      identificador: piece?.identificador ?? 'Sem ID',
      pecaNome: piece?.nomePeca ?? 'Peça',
      status: piece?.status ?? 'pendente',
      obraPecaId: p.obraPecaId,
    ));
  }
  itens.sort((a, b) => a.dataInicio.compareTo(b.dataInicio));
  return itens;
});
