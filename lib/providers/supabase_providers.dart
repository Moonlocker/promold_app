import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/supabase/supabase_service.dart';
import '../repositories/auth_repository.dart';
import '../repositories/configuracoes_repository.dart';
import '../repositories/dashboard_repository.dart';
import '../repositories/estoque_repository.dart';
import '../repositories/obra_historico_repository.dart';
import '../repositories/obra_insumos_repository.dart';
import '../repositories/obra_midia_repository.dart';
import '../repositories/obras_repository.dart';
import '../repositories/producao_repository.dart';
import '../repositories/processos_repository.dart';
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
