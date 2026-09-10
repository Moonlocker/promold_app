import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/logic/status_config.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/peca_status_chip.dart';
import '../../../models/obra_peca.dart';
import '../../../models/planejamento.dart';
import '../../../providers/auth_providers.dart';
import '../../../providers/obra_providers.dart';
import '../../../providers/planejamento_providers.dart';
import '../../../providers/supabase_providers.dart';
import '../../obras/widgets/obra_peca_edit_sheet.dart';
import '../widgets/planejar_sheet.dart';

/// Planejamento de armação, produção e montagem (módulo `planejamento`).
class PlanejamentoScreen extends ConsumerWidget {
  const PlanejamentoScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tipo = ref.watch(planejamentoTipoProvider);
    final isMontagem = tipo == 'montagem';
    final dia = ref.watch(planejamentoDiaProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Planejamento'),
        actions: [
          if (!isMontagem)
            IconButton(
              tooltip: 'Adicionar ao planejamento',
              icon: const Icon(Icons.add),
              onPressed: () => _adicionar(context, ref, tipo, dia),
            ),
        ],
      ),
      floatingActionButton: isMontagem
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _adicionar(context, ref, tipo, dia),
              icon: const Icon(Icons.add),
              label: const Text('Planejar'),
            ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: _Tabs(
              tipo: tipo,
              onChange: (v) =>
                  ref.read(planejamentoTipoProvider.notifier).set(v),
            ),
          ),
          const _SemanaNav(),
          Expanded(
            child: isMontagem ? const _MontagemList() : const _SemanaView(),
          ),
        ],
      ),
    );
  }

  Future<void> _adicionar(
    BuildContext context,
    WidgetRef ref,
    String tipo,
    DateTime dia,
  ) async {
    final salvou = await showPlanejarSheet(
      context,
      ref,
      tipo: tipo,
      diaInicial: dia,
    );
    if (salvou == true) {
      ref.invalidate(planejamentoDadosProvider);
    }
  }
}

class _Tabs extends StatelessWidget {
  const _Tabs({required this.tipo, required this.onChange});

  final String tipo;
  final ValueChanged<String> onChange;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.muted,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _TabBtn(
            label: 'Armação',
            icon: Icons.hardware_outlined,
            ativo: tipo == 'armacao',
            onTap: () => onChange('armacao'),
          ),
          _TabBtn(
            label: 'Produção',
            icon: Icons.water_drop_outlined,
            ativo: tipo == 'producao',
            onTap: () => onChange('producao'),
          ),
          _TabBtn(
            label: 'Montagem',
            icon: Icons.build_outlined,
            ativo: tipo == 'montagem',
            onTap: () => onChange('montagem'),
          ),
        ],
      ),
    );
  }
}

class _TabBtn extends StatelessWidget {
  const _TabBtn({
    required this.label,
    required this.icon,
    required this.ativo,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool ativo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(9),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: ativo ? AppColors.card : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            boxShadow: ativo
                ? const [
                    BoxShadow(
                      color: Color(0x14000000),
                      blurRadius: 4,
                      offset: Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 15,
                color: ativo ? AppColors.primary : AppColors.mutedForeground,
              ),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: ativo
                      ? AppColors.foreground
                      : AppColors.mutedForeground,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SemanaNav extends ConsumerWidget {
  const _SemanaNav();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final semana = ref.watch(planejamentoSemanaProvider);
    final fim = semana.add(const Duration(days: 6));
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          IconButton(
            onPressed: () =>
                ref.read(planejamentoSemanaProvider.notifier).anterior(),
            icon: const Icon(Icons.chevron_left),
            tooltip: 'Semana anterior',
          ),
          Expanded(
            child: Text(
              'Semana de ${Formatters.dataBr(semana)} a '
              '${Formatters.dataBr(fim)}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
          IconButton(
            onPressed: () =>
                ref.read(planejamentoSemanaProvider.notifier).proxima(),
            icon: const Icon(Icons.chevron_right),
            tooltip: 'Próxima semana',
          ),
        ],
      ),
    );
  }
}

class _SemanaView extends ConsumerWidget {
  const _SemanaView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dadosAsync = ref.watch(planejamentoDadosProvider);
    return dadosAsync.when(
      loading: () => const LoadingView(message: 'Carregando planejamento...'),
      error: (error, _) => ErrorView(
        message: error.toString(),
        onRetry: () => ref.invalidate(planejamentoDadosProvider),
      ),
      data: (dados) => Column(
        children: [
          _DiaStrip(dias: dados.dias),
          const Divider(height: 1),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async => ref.invalidate(planejamentoDadosProvider),
              child: _ItensDia(itens: dados.itensDoDia),
            ),
          ),
        ],
      ),
    );
  }
}

class _DiaStrip extends ConsumerWidget {
  const _DiaStrip({required this.dias});

  final List<PlanejamentoDia> dias;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selecionado = ref.watch(planejamentoDiaProvider);
    final selStr = Formatters.iso(selecionado);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          for (final d in dias)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: InkWell(
                  onTap: () =>
                      ref.read(planejamentoDiaProvider.notifier).set(d.dia),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: d.diaStr == selStr
                          ? AppColors.primary
                          : AppColors.card,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: d.diaStr == selStr
                            ? AppColors.primary
                            : AppColors.border,
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          d.diaNome,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: d.diaStr == selStr
                                ? Colors.white
                                : AppColors.mutedForeground,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${d.total}',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: d.diaStr == selStr
                                ? Colors.white
                                : AppColors.foreground,
                          ),
                        ),
                        if (d.total > 0)
                          Text(
                            '${d.concluidos}/${d.total}',
                            style: TextStyle(
                              fontSize: 9,
                              color: d.diaStr == selStr
                                  ? Colors.white70
                                  : AppColors.mutedForeground,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ItensDia extends ConsumerWidget {
  const _ItensDia({required this.itens});

  final List<PlanejamentoItem> itens;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (itens.isEmpty) {
      return ListView(
        children: const [
          SizedBox(height: 80),
          EmptyState(
            title: 'Nada planejado',
            message: 'Nenhuma peça planejada para este dia.',
            icon: Icons.event_available_outlined,
          ),
        ],
      );
    }

    final grupos = <String, List<PlanejamentoItem>>{};
    for (final item in itens) {
      grupos.putIfAbsent(item.obraId, () => []).add(item);
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final entry in grupos.entries) ...[
          _GrupoObra(
            itens: entry.value,
            onTap: (item) => _editar(context, ref, item),
            onRemover: (item) => _remover(context, ref, item),
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }

  Future<void> _editar(
    BuildContext context,
    WidgetRef ref,
    PlanejamentoItem item,
  ) async {
    if (item.obraPecaId == null) return;
    final pecas = await ref
        .read(obrasRepositoryProvider)
        .listPecas(item.obraId);
    ObraPeca? alvo;
    for (final p in pecas) {
      if (p.id == item.obraPecaId) {
        alvo = p;
        break;
      }
    }
    if (alvo == null || !context.mounted) return;
    final salvou = await showPecaEditSheet(
      context,
      ref,
      peca: alvo,
      todas: pecas,
    );
    if (salvou == true) {
      ref.invalidate(planejamentoDadosProvider);
      ref.invalidate(todasPecasResumoProvider);
    }
  }

  Future<void> _remover(
    BuildContext context,
    WidgetRef ref,
    PlanejamentoItem item,
  ) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remover do planejamento'),
        content: Text(
          'Remover ${item.identificador} do planejamento? '
          'A peça em si não será excluída.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.destructive,
            ),
            child: const Text('Remover'),
          ),
        ],
      ),
    );
    if (confirmar != true) return;
    await ref.read(producaoRepositoryProvider).removerPlanejamento(item.planId);
    ref.invalidate(planejamentoDadosProvider);
    ref.invalidate(planejamentoDiaExistenteProvider);
  }
}

class _GrupoObra extends StatelessWidget {
  const _GrupoObra({
    required this.itens,
    required this.onTap,
    required this.onRemover,
  });

  final List<PlanejamentoItem> itens;
  final ValueChanged<PlanejamentoItem> onTap;
  final ValueChanged<PlanejamentoItem> onRemover;

  @override
  Widget build(BuildContext context) {
    final first = itens.first;
    final cor = first.obraCor != null ? hexToColor(first.obraCor) : null;
    final concluidos = itens.where((i) => i.concluido).length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
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
                    first.obraNome,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  '$concluidos/${itens.length}',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: concluidos >= itens.length
                        ? AppColors.success
                        : AppColors.mutedForeground,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            for (final item in itens)
              _ItemLinha(
                item: item,
                onTap: () => onTap(item),
                onRemover: () => onRemover(item),
              ),
          ],
        ),
      ),
    );
  }
}

class _ItemLinha extends StatelessWidget {
  const _ItemLinha({
    required this.item,
    required this.onTap,
    required this.onRemover,
  });

  final PlanejamentoItem item;
  final VoidCallback onTap;
  final VoidCallback onRemover;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: item.obraPecaId != null ? onTap : null,
      onLongPress: onRemover,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.muted,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                item.identificador,
                style: const TextStyle(
                  fontSize: 11,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                item.pecaNome,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12.5),
              ),
            ),
            PecaStatusChip(status: item.status, compact: true),
            IconButton(
              onPressed: onRemover,
              icon: const Icon(
                Icons.delete_outline,
                size: 18,
                color: AppColors.destructive,
              ),
              tooltip: 'Remover do planejamento',
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
      ),
    );
  }
}

class _MontagemList extends ConsumerWidget {
  const _MontagemList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final montagemAsync = ref.watch(planejamentoMontagemProvider);
    final obras = ref.watch(obrasListProvider).value ?? const [];
    final obrasNome = {for (final o in obras) o.id: o.nome};

    return montagemAsync.when(
      loading: () => const LoadingView(),
      error: (error, _) => ErrorView(
        message: error.toString(),
        onRetry: () => ref.invalidate(planejamentoMontagemProvider),
      ),
      data: (lista) {
        if (lista.isEmpty) {
          return const EmptyState(
            title: 'Sem planejamento de montagem',
            message: 'Nenhuma montagem planejada para esta semana.',
            icon: Icons.build_outlined,
          );
        }
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(planejamentoMontagemProvider),
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: lista.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final m = lista[i];
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        obrasNome[m.obraId] ?? 'Obra',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${m.dataInicio} → ${m.dataFim}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.mutedForeground,
                        ),
                      ),
                      if (m.observacoes != null &&
                          m.observacoes!.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          m.observacoes!,
                          style: const TextStyle(fontSize: 12.5),
                        ),
                      ],
                      if (m.ocorrencias != null &&
                          m.ocorrencias!.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          m.ocorrencias!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.warning,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
