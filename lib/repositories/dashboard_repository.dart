import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/supabase/supabase_service.dart';
import '../core/utils/formatters.dart';
import '../models/dashboard_metrics.dart';
import '../models/obra.dart';

/// Consultas do dashboard. As mesmas fontes usadas pelo webapp:
/// `obras` e `obras_pecas` (produção = peças com `data_concretagem`).
class DashboardRepository {
  DashboardRepository({SupabaseClient? client})
      : _client = client ?? SupabaseService.client;

  final SupabaseClient _client;

  Future<DashboardMetrics> load() async {
    final hoje = Formatters.hojeBr();
    final (inicioSemana, fimSemana) = Formatters.semanaAtualBr();

    final results = await Future.wait([
      _obrasAtivas(),
      _producaoHoje(hoje),
      _pecasPendentes(),
      _concretoSemana(inicioSemana, fimSemana),
      _obrasPrioritarias(),
    ]);

    return DashboardMetrics(
      obrasAtivas: results[0] as int,
      producaoHoje: results[1] as int,
      pecasPendentes: results[2] as int,
      concretoSemanaM3: results[3] as double,
      obrasPrioritarias: results[4] as List<Obra>,
    );
  }

  Future<int> _obrasAtivas() {
    return _client.from('obras').count().eq('status', 'ativa');
  }

  Future<int> _pecasPendentes() {
    return _client.from('obras_pecas').count().eq('status', 'pendente');
  }

  Future<int> _producaoHoje(String hoje) {
    return _client
        .from('obras_pecas')
        .count()
        .eq('data_concretagem', hoje)
        .neq('status', 'pendente');
  }

  /// Concreto da semana = Σ (largura_padrão × altura_padrão × comprimento).
  Future<double> _concretoSemana(String inicio, String fim) async {
    final rows = await _client
        .from('obras_pecas')
        .select('comprimento, pecas_catalogo(largura_padrao, altura_padrao)')
        .not('data_concretagem', 'is', null)
        .neq('status', 'pendente')
        .gte('data_concretagem', inicio)
        .lte('data_concretagem', fim);

    var total = 0.0;
    for (final row in rows) {
      final map = Map<String, dynamic>.from(row);
      final peca = map['pecas_catalogo'];
      final largura = (peca is Map ? peca['largura_padrao'] : null) ?? 0;
      final altura = (peca is Map ? peca['altura_padrao'] : null) ?? 0;
      final comprimento = map['comprimento'] ?? 0;
      total += (largura as num) * (altura as num) * (comprimento as num);
    }
    return total;
  }

  Future<List<Obra>> _obrasPrioritarias() async {
    final rows = await _client
        .from('obras')
        .select()
        .eq('status', 'ativa')
        .order('prioridade', ascending: true)
        .limit(4);
    return rows.map((e) => Obra.fromMap(Map<String, dynamic>.from(e))).toList();
  }
}
