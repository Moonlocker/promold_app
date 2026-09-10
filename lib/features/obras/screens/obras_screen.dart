import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/logic/obra_alert.dart';
import '../../../core/logic/status_config.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/progress_ring.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../models/obra.dart';
import '../../../providers/auth_providers.dart';
import '../../../providers/obra_providers.dart';
import '../widgets/obra_form_sheet.dart';

const _statusFilters = [
  ('todas', 'Todas'),
  ('ativa', 'Ativas'),
  ('pausada', 'Pausadas'),
  ('planejamento', 'Planejamento'),
  ('concluida', 'Concluídas'),
];

/// Lista de obras da organização.
class ObrasScreen extends ConsumerStatefulWidget {
  const ObrasScreen({super.key});

  @override
  ConsumerState<ObrasScreen> createState() => _ObrasScreenState();
}

class _ObrasScreenState extends ConsumerState<ObrasScreen> {
  final _busca = TextEditingController();
  String _statusFiltro = 'ativa';

  @override
  void dispose() {
    _busca.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final obrasAsync = ref.watch(obrasListProvider);
    final pecasAsync = ref.watch(todasPecasResumoProvider);
    final statusCfg =
        ref.watch(statusConfigProvider).value ?? StatusConfig.defaults;

    return Scaffold(
      appBar: AppBar(title: const Text('Obras')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final ok = await showObraFormSheet(context, ref);
          if (ok == true && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Obra cadastrada!')),
            );
          }
        },
        icon: const Icon(Icons.add),
        label: const Text('Nova Obra'),
      ),
      body: obrasAsync.when(
        loading: () => const LoadingView(message: 'Carregando obras...'),
        error: (e, _) => ErrorView(
          message: e.toString(),
          onRetry: () => ref.invalidate(obrasListProvider),
        ),
        data: (obras) {
          final pecas = pecasAsync.value ?? const [];
          final porObra = <String, List<String>>{};
          for (final p in pecas) {
            porObra.putIfAbsent(p.obraId, () => []).add(p.status);
          }

          final termo = _busca.text.trim().toLowerCase();
          final filtradas = obras.where((o) {
            final matchStatus =
                _statusFiltro == 'todas' || o.status == _statusFiltro;
            final matchBusca = termo.isEmpty ||
                o.nome.toLowerCase().contains(termo) ||
                o.cliente.toLowerCase().contains(termo);
            return matchStatus && matchBusca;
          }).toList()
            ..sort((a, b) => a.prioridade.compareTo(b.prioridade));

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: TextField(
                  controller: _busca,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    hintText: 'Buscar obra ou cliente',
                    prefixIcon: Icon(Icons.search),
                    isDense: true,
                  ),
                ),
              ),
              SizedBox(
                height: 44,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _statusFilters.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (_, i) {
                    final (value, label) = _statusFilters[i];
                    return ChoiceChip(
                      label: Text(label),
                      selected: _statusFiltro == value,
                      onSelected: (_) => setState(() => _statusFiltro = value),
                    );
                  },
                ),
              ),
              const SizedBox(height: 4),
              Expanded(
                child: filtradas.isEmpty
                    ? const EmptyState(
                        icon: Icons.filter_alt_off_outlined,
                        title: 'Nenhuma obra encontrada',
                        message: 'Ajuste os filtros ou cadastre uma nova obra.',
                      )
                    : RefreshIndicator(
                        onRefresh: () async {
                          ref.invalidate(obrasListProvider);
                          ref.invalidate(todasPecasResumoProvider);
                        },
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                          itemCount: filtradas.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 10),
                          itemBuilder: (_, index) {
                            final obra = filtradas[index];
                            final statuses = porObra[obra.id] ?? const <String>[];
                            return _ObraCard(
                              obra: obra,
                              statuses: statuses,
                              statusCfg: statusCfg,
                            );
                          },
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ObraCard extends StatelessWidget {
  const _ObraCard({
    required this.obra,
    required this.statuses,
    required this.statusCfg,
  });

  final Obra obra;
  final List<String> statuses;
  final StatusConfig statusCfg;

  @override
  Widget build(BuildContext context) {
    final total = statuses.length;
    final montadas = statuses.where((s) => s == 'montada').length;
    final somaPeso =
        statuses.fold<double>(0, (acc, s) => acc + statusCfg.weightOf(s));
    final pct = total > 0 ? (somaPeso / total).round() : 0;
    final alerta = calculateObraAlertStatus(
      dataInicio: obra.dataInicio,
      dataPrevisao: obra.dataPrevisao,
      produzido: montadas,
      totalPecas: total,
    );
    final cor = hexToColor(obra.cor);

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push(AppRoutes.obraDetalhe(obra.id)),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text('#${obra.prioridade}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.mutedForeground,
                                  fontWeight: FontWeight.w600,
                                )),
                            const SizedBox(width: 8),
                            StatusBadge(status: obra.status),
                            if (alerta.needsAttention) ...[
                              const SizedBox(width: 6),
                              const Icon(Icons.warning_amber_rounded,
                                  size: 16, color: AppColors.warning),
                            ],
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            if (cor != null) ...[
                              Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: cor,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                            ],
                            Expanded(
                              child: Text(
                                obra.nome,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        Text(
                          obra.cliente,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.mutedForeground,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  ProgressRing(
                    value: pct.toDouble(),
                    size: 54,
                    strokeWidth: 5,
                    color: cor,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    '$montadas/$total peças',
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: AppColors.mutedForeground,
                    ),
                  ),
                  const Spacer(),
                  if (obra.dataPrevisao != null)
                    Text(
                      'Prev: ${Formatters.dataBr(obra.dataPrevisao)}',
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppColors.mutedForeground,
                      ),
                    ),
                ],
              ),
              if (obra.endereco != null && obra.endereco!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  obra.endereco!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: AppColors.mutedForeground,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
