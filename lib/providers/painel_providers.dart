import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/logic/obra_alert.dart';
import '../core/logic/painel_calc.dart';
import '../core/logic/status_config.dart';
import '../core/utils/formatters.dart';
import '../models/painel_fabrica.dart';
import 'auth_providers.dart';
import 'obra_providers.dart';
import 'supabase_providers.dart';

/// Painel selecionado: `producao` ou `armacao`.
class PainelTipoNotifier extends Notifier<String> {
  @override
  String build() => 'producao';

  void set(String value) => state = value;
}

final painelTipoProvider = NotifierProvider<PainelTipoNotifier, String>(
  PainelTipoNotifier.new,
);

/// Dia selecionado no painel.
class PainelDiaNotifier extends Notifier<DateTime> {
  @override
  DateTime build() {
    final agora = DateTime.now();
    return DateTime(agora.year, agora.month, agora.day);
  }

  void set(DateTime dia) => state = dia;
}

final painelDiaProvider = NotifierProvider<PainelDiaNotifier, DateTime>(
  PainelDiaNotifier.new,
);

/// Dados consolidados do Painel da Fábrica.
final painelDadosProvider = FutureProvider<PainelDados>((ref) async {
  final user = await ref.watch(appUserProvider.future);
  if (user == null) return PainelDados.empty;

  final tipo = ref.watch(painelTipoProvider);
  final isArmacao = tipo == 'armacao';
  final selecionado = ref.watch(painelDiaProvider);
  final hoje = DateTime.now();
  final inicio = inicioDaSemana(hoje);
  final fim = inicio.add(const Duration(days: 6));

  final repo = ref.watch(producaoRepositoryProvider);
  final planejamentos = await repo.listPlanejamento(
    Formatters.iso(inicio),
    Formatters.iso(fim),
    tipo: tipo,
  );

  final planIds = planejamentos
      .map((p) => p.obraPecaId)
      .whereType<String>()
      .toSet()
      .toList();
  final pecasPlanejadas = await repo.listPecasPorIds(planIds);
  final pecasPorId = {for (final p in pecasPlanejadas) p.id: p};

  final obras = await ref.watch(obrasListProvider.future);
  final catalogo = await ref.watch(pecasCatalogoProvider.future);
  final obrasPorId = {for (final o in obras) o.id: o};
  final catalogoPorId = {for (final c in catalogo) c.id: c};

  final dias = construirDiasResumo(
    inicio: inicio,
    planejamentos: planejamentos,
    pecasPorId: pecasPorId,
    isArmacao: isArmacao,
    hoje: hoje,
  );

  final diaStr = Formatters.iso(selecionado);
  final obrasDoDia = construirObrasDoDia(
    diaStr: diaStr,
    planejamentos: planejamentos,
    pecasPorId: pecasPorId,
    obrasPorId: obrasPorId,
    catalogoPorId: catalogoPorId,
    isArmacao: isArmacao,
  );

  final diaResumo = dias.firstWhere(
    (d) => d.diaStr == diaStr,
    orElse: () => PainelDiaResumo(
      dia: selecionado,
      diaStr: diaStr,
      diaNome: '',
      planejado: 0,
      produzido: 0,
      isHoje: diaStr == Formatters.iso(hoje),
    ),
  );

  final planejadoSemana = dias.fold<int>(0, (a, d) => a + d.planejado);
  final producaoSemana = dias.fold<int>(0, (a, d) => a + d.produzido);

  // Resumo por obra (progresso unificado + alerta de atraso).
  final todasPecas = await ref.watch(todasPecasResumoProvider.future);
  final processos = await ref.watch(processosEtapasProvider.future);
  final itens = await ref.watch(processosEtapasItensProvider.future);
  final etapaStatus = await ref.watch(obraEtapaStatusProvider.future);
  final weights = ref.watch(statusConfigProvider).value?.weights;

  final obrasResumo = <PainelObraResumo>[];
  for (final obra in obras.where((o) => o.status == 'ativa').take(6)) {
    final pecasObra = todasPecas.where((p) => p.obraId == obra.id).toList();
    final total = pecasObra.length;
    final produzido = pecasObra
        .where((p) => isRealizadoStatus(p.status, isArmacao))
        .length;
    final pendente = (total - produzido).clamp(0, 1 << 31);
    final percentual = computeProgressoGeral(
      obraId: obra.id,
      pecas: todasPecas,
      processos: processos,
      etapasItens: itens,
      etapaStatus: etapaStatus,
      weights: weights,
    );
    final alerta = calculateObraAlertStatus(
      dataInicio: obra.dataInicio,
      dataPrevisao: obra.dataPrevisao,
      produzido: produzido,
      totalPecas: total,
    );
    obrasResumo.add(
      PainelObraResumo(
        obraId: obra.id,
        nome: obra.nome,
        endereco: obra.endereco,
        cor: obra.cor,
        totalPecas: total,
        produzido: produzido,
        pendente: pendente,
        percentual: percentual,
        needsAttention: alerta.needsAttention,
      ),
    );
  }
  obrasResumo.sort((a, b) {
    if (a.needsAttention != b.needsAttention) {
      return a.needsAttention ? -1 : 1;
    }
    return b.pendente - a.pendente;
  });

  return PainelDados(
    diasSemana: dias,
    obrasDoDia: obrasDoDia,
    obrasResumo: obrasResumo,
    planejadoDia: diaResumo.planejado,
    producaoDia: diaResumo.produzido,
    planejadoSemana: planejadoSemana,
    producaoSemana: producaoSemana,
  );
});
