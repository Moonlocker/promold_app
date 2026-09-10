import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/logic/status_config.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_image.dart';
import '../../../core/widgets/peca_status_chip.dart';
import '../../../core/widgets/progress_ring.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../models/obra.dart';
import '../../../models/obra_peca.dart';
import '../../../providers/obra_providers.dart';
import '../../../providers/supabase_providers.dart';

/// Aba "Visão Geral" da obra (porte de `ObraVisaoGeralTab.tsx`).
class ObraVisaoGeralTab extends ConsumerWidget {
  const ObraVisaoGeralTab({
    super.key,
    required this.obra,
    required this.onVerPecas,
  });

  final Obra obra;
  final VoidCallback onVerPecas;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pecasAsync = ref.watch(obrasPecasProvider(obra.id));
    final statusCfg = ref.watch(statusConfigProvider).value ??
        StatusConfig.defaults;
    final processos = ref.watch(processosEtapasProvider).value ?? const [];
    final etapasItens = ref.watch(processosEtapasItensProvider).value ?? const [];
    final etapaStatus = ref.watch(obraEtapaStatusProvider).value ?? const [];

    return pecasAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Erro: $e')),
      data: (pecas) {
        final total = pecas.length;
        final produzidas = pecas.where((p) => statusConcluido(p.status)).length;
        final progresso = computeProgressoGeral(
          obraId: obra.id,
          pecas: pecas,
          processos: processos,
          etapasItens: etapasItens,
          etapaStatus: etapaStatus,
          weights: statusCfg.weights,
        );

        final contagem = <String, int>{};
        for (final p in pecas) {
          final s = normalizarStatus(p.status);
          contagem[s] = (contagem[s] ?? 0) + 1;
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _HeaderCard(obra: obra),
            const SizedBox(height: 14),
            _ProgressoCard(
              progresso: progresso,
              produzidas: produzidas,
              total: total,
            ),
            const SizedBox(height: 14),
            _StatusCards(
              contagem: contagem,
              statusCfg: statusCfg,
              onTap: (status) {
                ref.read(obraPecasFilterProvider.notifier).set(status);
                onVerPecas();
              },
            ),
            const SizedBox(height: 20),
            _CategoriasSection(pecas: pecas, statusCfg: statusCfg),
            const SizedBox(height: 20),
            _ProcessosSection(obraId: obra.id),
          ],
        );
      },
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.obra});

  final Obra obra;

  @override
  Widget build(BuildContext context) {
    final cor = hexToColor(obra.cor);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppColors.muted,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: AppImage(
                    url: obra.fotoUrl,
                    placeholder: const Icon(Icons.business_outlined,
                        color: AppColors.mutedForeground),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
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
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        obra.cliente,
                        style: const TextStyle(
                          color: AppColors.mutedForeground,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 6),
                      StatusBadge(status: obra.status),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _meta(Icons.place_outlined, obra.endereco ?? 'Endereço não informado'),
            _meta(Icons.play_circle_outline,
                'Início: ${Formatters.dataBr(obra.dataInicio)}'),
            _meta(Icons.flag_outlined,
                'Previsão: ${Formatters.dataBr(obra.dataPrevisao)}'),
            _meta(Icons.sort, 'Prioridade #${obra.prioridade}'),
            if (obra.observacoes != null && obra.observacoes!.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.muted,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  obra.observacoes!,
                  style: const TextStyle(fontSize: 12.5),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _meta(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(icon, size: 15, color: AppColors.mutedForeground),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 12.5,
                color: AppColors.mutedForeground,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressoCard extends StatelessWidget {
  const _ProgressoCard({
    required this.progresso,
    required this.produzidas,
    required this.total,
  });

  final int progresso;
  final int produzidas;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            ProgressRing(value: progresso.toDouble(), size: 96, strokeWidth: 9),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Progresso geral',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$produzidas de $total peças produzidas',
                    style: const TextStyle(
                      color: AppColors.mutedForeground,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusCards extends StatelessWidget {
  const _StatusCards({
    required this.contagem,
    required this.statusCfg,
    required this.onTap,
  });

  final Map<String, int> contagem;
  final StatusConfig statusCfg;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 92,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: statusSelecionaveis.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (_, index) {
          final status = statusSelecionaveis[index];
          final color = statusCfg.colorOf(status);
          return InkWell(
            onTap: () => onTap(status),
            borderRadius: BorderRadius.circular(14),
            child: Container(
              width: 104,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 30,
                    height: 4,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${contagem[status] ?? 0}',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    statusLabel(status),
                    style: TextStyle(
                      fontSize: 11.5,
                      color: color,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _CategoriasSection extends ConsumerWidget {
  const _CategoriasSection({required this.pecas, required this.statusCfg});

  final List<ObraPeca> pecas;
  final StatusConfig statusCfg;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final porCategoria = <String, List<ObraPeca>>{};
    for (final p in pecas) {
      final cat = p.pecaCatalogo?.categoria;
      final key = cat?.nome ?? 'Sem categoria';
      porCategoria.putIfAbsent(key, () => []).add(p);
    }

    if (porCategoria.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('Nenhuma peça cadastrada.',
              style: TextStyle(color: AppColors.mutedForeground)),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Peças por categoria',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Card(
          child: Column(
            children: porCategoria.entries.map((entry) {
              final lista = entry.value;
              final total = lista.length;
              final somaPeso = lista.fold<double>(
                  0, (acc, p) => acc + statusCfg.weightOf(p.status));
              final pct = total > 0 ? (somaPeso / total).round() : 0;
              return ExpansionTile(
                title: Text(entry.key,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600)),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Text('$total peças · $pct%',
                        style: const TextStyle(fontSize: 12)),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: pct / 100,
                        minHeight: 6,
                        backgroundColor: AppColors.muted,
                      ),
                    ),
                  ],
                ),
                children: lista
                    .map((p) => ListTile(
                          dense: true,
                          title: Text(p.identificador.isEmpty
                              ? p.nomePeca
                              : '${p.identificador} · ${p.nomePeca}'),
                          trailing: PecaStatusChip(
                            status: p.status,
                            colors: statusCfg.colors,
                            compact: true,
                          ),
                        ))
                    .toList(),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class _ProcessosSection extends ConsumerWidget {
  const _ProcessosSection({required this.obraId});

  final String obraId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final processosAsync = ref.watch(processosEtapasProvider);
    final itensAsync = ref.watch(processosEtapasItensProvider);
    final statusAsync = ref.watch(obraEtapaStatusProvider);

    return processosAsync.maybeWhen(
      data: (processos) {
        final itens = itensAsync.value ?? const [];
        final status = statusAsync.value ?? const [];
        final comItens =
            processos.where((p) => itens.any((it) => it.processoId == p.id));
        if (comItens.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Processos / Etapas',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: comItens.map((proc) {
                  final etapas =
                      itens.where((it) => it.processoId == proc.id).toList();
                  final concluido = etapas.where((it) {
                    final s = status
                        .where((x) =>
                            x.obraId == obraId && x.etapaItemId == it.id)
                        .toList();
                    return (s.isNotEmpty ? s.first.status : 'pendente') ==
                        'concluido';
                  }).length;
                  final pct = etapas.isEmpty
                      ? 0
                      : ((concluido / etapas.length) * 100).round();
                  return ExpansionTile(
                    title: Text(proc.nome,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600)),
                    subtitle: Text('$concluido/${etapas.length} etapas · $pct%',
                        style: const TextStyle(fontSize: 12)),
                    children: etapas.map((it) {
                      final s = status
                          .where((x) =>
                              x.obraId == obraId && x.etapaItemId == it.id)
                          .toList();
                      final atual = s.isNotEmpty ? s.first.status : 'pendente';
                      return ListTile(
                        dense: true,
                        title: Text(it.nome),
                        trailing: _EtapaStatusButton(
                          status: atual,
                          onTap: () async {
                            final proximo = atual == 'pendente'
                                ? 'em_andamento'
                                : atual == 'em_andamento'
                                    ? 'concluido'
                                    : 'pendente';
                            await ref
                                .read(processosRepositoryProvider)
                                .upsertStatus(
                                  obraId: obraId,
                                  etapaItemId: it.id,
                                  status: proximo,
                                );
                            ref.invalidate(obraEtapaStatusProvider);
                          },
                        ),
                      );
                    }).toList(),
                  );
                }).toList(),
              ),
            ),
          ],
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}

class _EtapaStatusButton extends StatelessWidget {
  const _EtapaStatusButton({required this.status, required this.onTap});

  final String status;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      'concluido' => ('Concluído', AppColors.success),
      'em_andamento' => ('Em andamento', AppColors.info),
      _ => ('Pendente', AppColors.mutedForeground),
    };
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 32),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        side: BorderSide(color: color.withValues(alpha: 0.4)),
        foregroundColor: color,
      ),
      child: Text(label, style: const TextStyle(fontSize: 12)),
    );
  }
}
