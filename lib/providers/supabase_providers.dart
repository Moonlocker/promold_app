import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/supabase/supabase_service.dart';
import '../repositories/auth_repository.dart';
import '../repositories/capacidade_repository.dart';
import '../repositories/clientes_repository.dart';
import '../repositories/configuracoes_repository.dart';
import '../repositories/dashboard_repository.dart';
import '../repositories/equipe_repository.dart';
import '../repositories/estoque_repository.dart';
import '../repositories/financeiro_cadastros_repository.dart';
import '../repositories/financeiro_repository.dart';
import '../repositories/fiscal_repository.dart';
import '../repositories/feriados_repository.dart';
import '../repositories/fornecedores_repository.dart';
import '../repositories/mapa_montagem_repository.dart';
import '../repositories/obra_historico_repository.dart';
import '../repositories/obra_ifc_repository.dart';
import '../repositories/obra_insumos_repository.dart';
import '../repositories/obra_midia_repository.dart';
import '../repositories/obras_repository.dart';
import '../repositories/onboarding_repository.dart';
import '../repositories/orcamento_composicoes_repository.dart';
import '../repositories/pecas_catalogo_repository.dart';
import '../repositories/producao_repository.dart';
import '../repositories/processos_repository.dart';
import '../repositories/qualidade_repository.dart';
import '../repositories/sistema_repository.dart';
import '../repositories/superadmin_repository.dart';
import '../repositories/user_management_repository.dart';
import '../services/auth_service.dart';
import '../services/leitor_service.dart';

/// Providers de infraestrutura. Um único client Supabase é compartilhado por
/// toda a aplicação.
final supabaseClientProvider = Provider<SupabaseClient>(
  (ref) => SupabaseService.client,
);

final authServiceProvider = Provider<AuthService>(
  (ref) => AuthService(client: ref.watch(supabaseClientProvider)),
);

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(client: ref.watch(supabaseClientProvider)),
);

final dashboardRepositoryProvider = Provider<DashboardRepository>(
  (ref) => DashboardRepository(client: ref.watch(supabaseClientProvider)),
);

final obrasRepositoryProvider = Provider<ObrasRepository>(
  (ref) => ObrasRepository(client: ref.watch(supabaseClientProvider)),
);

final producaoRepositoryProvider = Provider<ProducaoRepository>(
  (ref) => ProducaoRepository(client: ref.watch(supabaseClientProvider)),
);

final obraMidiaRepositoryProvider = Provider<ObraMidiaRepository>(
  (ref) => ObraMidiaRepository(client: ref.watch(supabaseClientProvider)),
);

final obraHistoricoRepositoryProvider = Provider<ObraHistoricoRepository>(
  (ref) => ObraHistoricoRepository(client: ref.watch(supabaseClientProvider)),
);

final obraInsumosRepositoryProvider = Provider<ObraInsumosRepository>(
  (ref) => ObraInsumosRepository(client: ref.watch(supabaseClientProvider)),
);

final obraIfcRepositoryProvider = Provider<ObraIfcRepository>(
  (ref) => ObraIfcRepository(client: ref.watch(supabaseClientProvider)),
);

final processosRepositoryProvider = Provider<ProcessosRepository>(
  (ref) => ProcessosRepository(client: ref.watch(supabaseClientProvider)),
);

final estoqueRepositoryProvider = Provider<EstoqueRepository>(
  (ref) => EstoqueRepository(client: ref.watch(supabaseClientProvider)),
);

final leitorServiceProvider = Provider<LeitorService>(
  (ref) => LeitorService(client: ref.watch(supabaseClientProvider)),
);

final configuracoesRepositoryProvider = Provider<ConfiguracoesRepository>(
  (ref) => ConfiguracoesRepository(client: ref.watch(supabaseClientProvider)),
);

final clientesRepositoryProvider = Provider<ClientesRepository>(
  (ref) => ClientesRepository(client: ref.watch(supabaseClientProvider)),
);

final fornecedoresRepositoryProvider = Provider<FornecedoresRepository>(
  (ref) => FornecedoresRepository(client: ref.watch(supabaseClientProvider)),
);

final financeiroCadastrosRepositoryProvider =
    Provider<FinanceiroCadastrosRepository>(
  (ref) => FinanceiroCadastrosRepository(
    client: ref.watch(supabaseClientProvider),
  ),
);

final equipeRepositoryProvider = Provider<EquipeRepository>(
  (ref) => EquipeRepository(client: ref.watch(supabaseClientProvider)),
);

final pecasCatalogoRepositoryProvider = Provider<PecasCatalogoRepository>(
  (ref) => PecasCatalogoRepository(client: ref.watch(supabaseClientProvider)),
);

final financeiroRepositoryProvider = Provider<FinanceiroRepository>(
  (ref) => FinanceiroRepository(client: ref.watch(supabaseClientProvider)),
);

final qualidadeRepositoryProvider = Provider<QualidadeRepository>(
  (ref) => QualidadeRepository(client: ref.watch(supabaseClientProvider)),
);

final fiscalRepositoryProvider = Provider<FiscalRepository>(
  (ref) => FiscalRepository(client: ref.watch(supabaseClientProvider)),
);

final sistemaRepositoryProvider = Provider<SistemaRepository>(
  (ref) => SistemaRepository(client: ref.watch(supabaseClientProvider)),
);

final mapaMontagemRepositoryProvider = Provider<MapaMontagemRepository>(
  (ref) => MapaMontagemRepository(client: ref.watch(supabaseClientProvider)),
);

final userManagementRepositoryProvider = Provider<UserManagementRepository>(
  (ref) => UserManagementRepository(client: ref.watch(supabaseClientProvider)),
);

final capacidadeRepositoryProvider = Provider<CapacidadeRepository>(
  (ref) => CapacidadeRepository(client: ref.watch(supabaseClientProvider)),
);

final onboardingRepositoryProvider = Provider<OnboardingRepository>(
  (ref) => OnboardingRepository(client: ref.watch(supabaseClientProvider)),
);

final feriadosRepositoryProvider = Provider<FeriadosRepository>(
  (ref) => FeriadosRepository(client: ref.watch(supabaseClientProvider)),
);

final orcamentoComposicoesRepositoryProvider =
    Provider<OrcamentoComposicoesRepository>(
  (ref) => OrcamentoComposicoesRepository(
    client: ref.watch(supabaseClientProvider),
  ),
);

final superAdminRepositoryProvider = Provider<SuperAdminRepository>(
  (ref) => SuperAdminRepository(client: ref.watch(supabaseClientProvider)),
);
