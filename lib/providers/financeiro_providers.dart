import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/conta_financeira.dart';
import 'supabase_providers.dart';

/// Contas a pagar.
final contasPagarListProvider = FutureProvider<List<ContaFinanceira>>(
  (ref) => ref.watch(financeiroRepositoryProvider).listContas('pagar'),
);

/// Contas a receber.
final contasReceberListProvider = FutureProvider<List<ContaFinanceira>>(
  (ref) => ref.watch(financeiroRepositoryProvider).listContas('receber'),
);

/// Configuração da integração Asaas da organização.
final integracaoFinanceiraProvider = FutureProvider<Map<String, dynamic>?>(
  (ref) => ref.watch(financeiroRepositoryProvider).getIntegracao(),
);
