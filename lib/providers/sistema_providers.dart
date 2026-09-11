import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/sistema.dart';
import '../models/veiculo.dart';
import 'supabase_providers.dart';

/// Veículos da frota.
final veiculosListProvider = FutureProvider<List<Veiculo>>(
  (ref) => ref.watch(sistemaRepositoryProvider).listVeiculos(),
);

/// Tickets de suporte da organização.
final ticketsListProvider = FutureProvider<List<SupportTicket>>(
  (ref) => ref.watch(sistemaRepositoryProvider).listTickets(),
);

/// Mensagens de um ticket.
final ticketMessagesProvider =
    FutureProvider.family<List<SupportMessage>, String>(
  (ref, ticketId) => ref.watch(sistemaRepositoryProvider).listMessages(ticketId),
);

/// Usuários da organização (profiles).
final usuariosListProvider = FutureProvider<List<Map<String, dynamic>>>(
  (ref) => ref.watch(sistemaRepositoryProvider).listUsuarios(),
);

/// Faturas SaaS da organização.
final faturasSaasProvider = FutureProvider<List<FaturaSaas>>(
  (ref) => ref.watch(sistemaRepositoryProvider).listFaturas(),
);

/// Orçamentos da organização.
final orcamentosListProvider = FutureProvider<List<Orcamento>>(
  (ref) => ref.watch(sistemaRepositoryProvider).listOrcamentos(),
);

/// Itens de um orçamento.
final orcamentoItensProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>(
  (ref, orcamentoId) =>
      ref.watch(sistemaRepositoryProvider).listOrcamentoItens(orcamentoId),
);

/// Orçamento individual.
final orcamentoProvider = FutureProvider.family<Orcamento?, String>(
  (ref, id) => ref.watch(sistemaRepositoryProvider).getOrcamento(id),
);

/// Etapas de um orçamento.
final orcamentoEtapasProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>(
  (ref, orcamentoId) =>
      ref.watch(orcamentoComposicoesRepositoryProvider).listEtapas(orcamentoId),
);

/// Composições de uma etapa.
final orcamentoComposicoesProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>(
  (ref, etapaId) =>
      ref.watch(orcamentoComposicoesRepositoryProvider).listComposicoes(etapaId),
);

/// Insumos de uma composição do orçamento.
final orcamentoComposicaoInsumosProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>(
  (ref, orcamentoComposicaoId) => ref
      .watch(orcamentoComposicoesRepositoryProvider)
      .listComposicaoInsumos(orcamentoComposicaoId),
);

/// Soma dos custos das composições (etapas) do orçamento.
final orcamentoComposicoesTotalProvider =
    FutureProvider.family<double, String>(
  (ref, orcamentoId) =>
      ref.watch(orcamentoComposicoesRepositoryProvider).totalOrcamento(orcamentoId),
);
