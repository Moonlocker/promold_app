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
import '../../../services/planejamento_semanal_pdf_service.dart';
import '../../obras/widgets/obra_peca_edit_sheet.dart';
import '../widgets/gerenciar_feriados_sheet.dart';
import '../widgets/planejar_sheet.dart';

/// Planejamento de armação, produção e montagem (módulo `planejamento`).
class PlanejamentoScreen extends ConsumerWidget {
  const PlanejamentoScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tipo = ref.watch(planejamentoTipoProvider);
    final isMontagem = tipo == 'montagem';
    final dia = ref.watch(planejamentoDiaProvider);
    final modo = ref.watch(planejamentoViewModeProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Planejamento'),
        actions: [
          IconButton(
            tooltip: 'Feriados',
            icon: const Icon(Icons.event_busy_outlined),
            onPressed: () => showGerenciarFeriadosSheet(context),
          ),
          if (!isMontagem)
            IconButton(
              tooltip: 'Exportar PDF',
              icon: const Icon(Icons.picture_as_pdf),
              onPressed: () => _exportarPdf(context, ref, tipo),
            ),
          if (!isMontagem)
            IconButton(
              tooltip: 'Adicionar ao planejamento',
              icon: const Icon(Icons.add),
              onPressed: () => _adicionar(context, ref, tipo, dia),
            ),
          if (!isMontagem)
            PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'limpar') _limparSemana(context, ref, tipo);
              },
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'limpar',
                  child: Text('Limpar semana',
                      style: TextStyle(color: AppColors.destructive)),
                ),
              ],
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
          if (!isMontagem)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: _ViewToggle(
                modo: modo,
                onChange: (v) =>
                    ref.read(planejamentoViewModeProvider.notifier).set(v),
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

  Future<void> _exportarPdf(
    BuildContext context,
    WidgetRef ref,
    String tipo,
  ) async {
    final dados = ref.read(planejamentoDadosProvider).value;
    if (dados == null) return;
    final modo = ref.read(planejamentoViewModeProvider);
    final String periodo;
    if (modo == 'mensal') {
      periodo = Formatters.mesAno(ref.read(planejamentoMesProvider));
    } else {
      final semana = ref.read(planejamentoSemanaProvider);
      periodo = '${Formatters.dataBr(semana)} a '
          '${Formatters.dataBr(semana.add(const Duration(days: 6)))}';
    }
    try {
      await PlanejamentoSemanalPdfService.gerar(
        tipo: tipo,
        periodLabel: periodo,
        dados: dados,
        organizacaoNome: ref.usuario?.organizacao?.nome,
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erro ao gerar PDF: $e')));
      }
    }
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

  Future<void> _limparSemana(
    BuildContext context,
    WidgetRef ref,
    String tipo,
  ) async {
    final semana = ref.read(planejamentoSemanaProvider);
    final fim = semana.add(const Duration(days: 6));
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Limpar semana'),
        content: Text(
          'Remover todos os planejamentos de '
          '${tipo == 'armacao' ? 'armação' : 'produção'} desta semana? '
          'As peças não serão excluídas.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: AppColors.destructive),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Limpar'),
          ),
        ],
      ),
    );
    if (confirmar != true) return;
    final n = await ref.read(producaoRepositoryProvider).limparPeriodo(
          Formatters.iso(semana),
          Formatters.iso(fim),
          tipo,
        );
    ref.invalidate(planejamentoDadosProvider);
    ref.invalidate(planejamentoDiaExistenteProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$n planejamento(s) removido(s)')),
      );
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
    final modo = ref.watch(planejamentoViewModeProvider);
    if (modo == 'mensal') {
      final mes = ref.watch(planejamentoMesProvider);
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          children: [
            IconButton(
              onPressed: () =>
                  ref.read(planejamentoMesProvider.notifier).anterior(),
              icon: const Icon(Icons.chevron_left),
              tooltip: 'Mês anterior',
            ),
            Expanded(
              child: Text(
                Formatters.mesAno(mes),
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
            IconButton(
              onPressed: () =>
                  ref.read(planejamentoMesProvider.notifier).proxima(),
              icon: const Icon(Icons.chevron_right),
              tooltip: 'Próximo mês',
            ),
          ],
        ),
      );
    }
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

class _ViewToggle extends StatelessWidget {
  const _ViewToggle({required this.modo, required this.onChange});

  final String modo;
  final ValueChanged<String> onChange;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: SegmentedButton<String>(
        showSelectedIcon: false,
        style: const ButtonStyle(
          visualDensity: VisualDensity.compact,
        ),
        segments: const [
          ButtonSegment(
            value: 'semanal',
            label: Text('Semana', style: TextStyle(fontSize: 12)),
            icon: Icon(Icons.view_week_outlined, size: 15),
          ),
          ButtonSegment(
            value: 'mensal',
            label: Text('Mês', style: TextStyle(fontSize: 12)),
            icon: Icon(Icons.calendar_month_outlined, size: 15),
          ),
        ],
        selected: {modo},
        onSelectionChanged: (s) => onChange(s.first),
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
          if (ref.watch(planejamentoViewModeProvider) == 'mensal')
            _MesGrid(dias: dados.dias)
          else
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
    final cap = ref.watch(capacidadeDiariaTotalProvider).value ?? 0;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          for (final d in dias)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: DragTarget<String>(
                  onWillAcceptWithDetails: (details) =>
                      details.data.isNotEmpty && d.diaStr != selStr,
                  onAcceptWithDetails: (details) =>
                      moverObraParaDia(context, ref, details.data, d.diaStr),
                  builder: (context, candidate, _) => _diaCell(
                    context,
                    ref,
                    d,
                    selStr,
                    cap,
                    candidate.isNotEmpty,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _diaCell(
    BuildContext context,
    WidgetRef ref,
    PlanejamentoDia d,
    String selStr,
    double cap,
    bool hovering,
  ) {
    final selecionado = d.diaStr == selStr;
    final excedido = cap > 0 && d.total > cap;
    final textColor = selecionado ? Colors.white : AppColors.foreground;
    final subColor = selecionado ? Colors.white70 : AppColors.mutedForeground;
    return InkWell(
      onTap: () => ref.read(planejamentoDiaProvider.notifier).set(d.dia),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
        decoration: BoxDecoration(
          color: hovering
              ? AppColors.primary.withValues(alpha: 0.18)
              : selecionado
                  ? AppColors.primary
                  : AppColors.card,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: excedido
                ? AppColors.destructive
                : selecionado
                    ? AppColors.primary
                    : AppColors.border,
            width: excedido ? 1.6 : 1,
          ),
        ),
        child: Column(
          children: [
            Text(
              d.diaNome,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: selecionado ? Colors.white : AppColors.mutedForeground,
              ),
            ),
            const SizedBox(height: 2),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${d.total}',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: textColor,
                  ),
                ),
                if (excedido)
                  Padding(
                    padding: const EdgeInsets.only(left: 2),
                    child: Icon(
                      Icons.warning_amber_rounded,
                      size: 12,
                      color: selecionado ? Colors.white : AppColors.destructive,
                    ),
                  ),
              ],
            ),
            if (d.total > 0)
              Text(
                '${d.concluidos}/${d.total}',
                style: TextStyle(fontSize: 9, color: subColor),
              ),
          ],
        ),
      ),
    );
  }
}

class _MesGrid extends ConsumerWidget {
  const _MesGrid({required this.dias});

  final List<PlanejamentoDia> dias;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selecionado = ref.watch(planejamentoDiaProvider);
    final selStr = Formatters.iso(selecionado);
    final cap = ref.watch(capacidadeDiariaTotalProvider).value ?? 0;
    if (dias.isEmpty) return const SizedBox.shrink();

    const cabecalho = ['dom', 'seg', 'ter', 'qua', 'qui', 'sex', 'sáb'];
    final semanas = <List<PlanejamentoDia>>[];
    for (var i = 0; i < dias.length; i += 7) {
      semanas.add(dias.sublist(i, (i + 7).clamp(0, dias.length)));
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
      child: Column(
        children: [
          Row(
            children: [
              for (final c in cabecalho)
                Expanded(
                  child: Center(
                    child: Text(c,
                        style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppColors.mutedForeground)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          for (final semana in semanas)
            Row(
              children: [
                for (final d in semana)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(1.5),
                      child: DragTarget<String>(
                        onWillAcceptWithDetails: (details) =>
                            details.data.isNotEmpty && d.diaStr != selStr,
                        onAcceptWithDetails: (details) => moverObraParaDia(
                            context, ref, details.data, d.diaStr),
                        builder: (context, candidate, _) => _celula(
                          context,
                          ref,
                          d,
                          selStr,
                          cap,
                          candidate.isNotEmpty,
                        ),
                      ),
                    ),
                  ),
                if (semana.length < 7)
                  for (var i = semana.length; i < 7; i++)
                    const Expanded(child: SizedBox()),
              ],
            ),
        ],
      ),
    );
  }

  Widget _celula(
    BuildContext context,
    WidgetRef ref,
    PlanejamentoDia d,
    String selStr,
    double cap,
    bool hovering,
  ) {
    final selecionado = d.diaStr == selStr;
    final excedido = cap > 0 && d.total > cap;
    return InkWell(
      onTap: () => ref.read(planejamentoDiaProvider.notifier).set(d.dia),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 46,
        decoration: BoxDecoration(
          color: hovering
              ? AppColors.primary.withValues(alpha: 0.18)
              : selecionado
                  ? AppColors.primary
                  : AppColors.card,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: excedido
                ? AppColors.destructive
                : selecionado
                    ? AppColors.primary
                    : AppColors.border,
            width: excedido ? 1.5 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${d.dia.day}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: selecionado ? Colors.white : AppColors.foreground,
              ),
            ),
            if (d.total > 0)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${d.total}',
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w600,
                      color: selecionado
                          ? Colors.white70
                          : AppColors.mutedForeground,
                    ),
                  ),
                  if (excedido)
                    Icon(Icons.warning_amber_rounded,
                        size: 10,
                        color:
                            selecionado ? Colors.white : AppColors.destructive),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

Future<void> moverObraParaDia(
  BuildContext context,
  WidgetRef ref,
  String obraId,
  String toDate,
) async {
  final from = Formatters.iso(ref.read(planejamentoDiaProvider));
  if (obraId.isEmpty || from == toDate) return;
  final tipo = ref.read(planejamentoTipoProvider);
  if (tipo == 'montagem') return;
  try {
    final n = await ref.read(producaoRepositoryProvider).moverObraDia(
          obraId: obraId,
          fromDate: from,
          toDate: toDate,
          tipo: tipo,
        );
    ref.invalidate(planejamentoDadosProvider);
    ref.invalidate(planejamentoDiaExistenteProvider);
    // Seleciona o dia de destino para visualizar o resultado.
    ref.read(planejamentoDiaProvider.notifier).set(DateTime.parse(toDate));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(n > 0
              ? '$n peça(s) movida(s) para ${Formatters.dataBr(DateTime.parse(toDate))}'
              : 'Nada para mover'),
        ),
      );
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Erro ao mover: $e')));
    }
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

    final tipo = ref.watch(planejamentoTipoProvider);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final entry in grupos.entries) ...[
          Builder(
            builder: (context) {
              final grupo = _GrupoObra(
                itens: entry.value,
                mostrarProduzir: tipo == 'producao',
                onTap: (item) => _editar(context, ref, item),
                onRemover: (item) => _remover(context, ref, item),
                onReagendar: (item) => _reagendar(context, ref, item),
                onReplicar: (item) => _replicar(context, ref, item),
                onMarcarProduzido: () =>
                    _marcarProduzido(context, ref, entry.value),
              );
              return LongPressDraggable<String>(
                data: entry.value.first.obraId,
                feedback: Material(
                  color: Colors.transparent,
                  child: _DragFeedback(nome: entry.value.first.obraNome),
                ),
                childWhenDragging: Opacity(opacity: 0.4, child: grupo),
                child: grupo,
              );
            },
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }

  Future<void> _reagendar(
    BuildContext context,
    WidgetRef ref,
    PlanejamentoItem item,
  ) async {
    final data = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (data == null) return;
    await ref
        .read(producaoRepositoryProvider)
        .reagendarPlanejamento(item.planId, Formatters.iso(data));
    ref.invalidate(planejamentoDadosProvider);
    ref.invalidate(planejamentoDiaExistenteProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Peça reagendada')),
      );
    }
  }

  Future<void> _replicar(
    BuildContext context,
    WidgetRef ref,
    PlanejamentoItem item,
  ) async {
    final data = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (data == null) return;
    await ref
        .read(producaoRepositoryProvider)
        .duplicarPlanejamento(item.planId, Formatters.iso(data));
    ref.invalidate(planejamentoDadosProvider);
    ref.invalidate(planejamentoDiaExistenteProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Peça replicada para a nova data')),
      );
    }
  }

  Future<void> _marcarProduzido(
    BuildContext context,
    WidgetRef ref,
    List<PlanejamentoItem> itens,
  ) async {
    final pendentes = itens
        .where((i) => i.obraPecaId != null && !i.concluido)
        .toList();
    if (pendentes.isEmpty) return;

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Marcar como produzido'),
        content: Text(
          'Marcar ${pendentes.length} peça(s) de '
          '${pendentes.first.obraNome} como produzida(s)? '
          'O status será "Em Estoque" e a data de concretagem será '
          'preenchida (quando ainda não houver).',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Produzir'),
          ),
        ],
      ),
    );
    if (confirmar != true) return;

    final hoje = DateTime.now().toIso8601String().split('T').first;
    final repo = ref.read(obrasRepositoryProvider);
    try {
      final pecas = await repo.listPecas(pendentes.first.obraId);
      final porId = {for (final p in pecas) p.id: p};
      for (final i in pendentes) {
        final p = porId[i.obraPecaId];
        final update = <String, dynamic>{'status': 'em_estoque'};
        if (p?.dataConcretagem == null) update['data_concretagem'] = hoje;
        await repo.updatePeca(i.obraPecaId!, update);
      }
      ref.invalidate(planejamentoDadosProvider);
      ref.invalidate(todasPecasResumoProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('${pendentes.length} peça(s) marcada(s) como '
                  'produzida(s)')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erro: $e')));
      }
    }
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

class _DragFeedback extends StatelessWidget {
  const _DragFeedback({required this.nome});

  final String nome;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(10),
        boxShadow: const [
          BoxShadow(
              color: Color(0x33000000), blurRadius: 8, offset: Offset(0, 3)),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.drag_indicator, size: 16, color: Colors.white),
          const SizedBox(width: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 200),
            child: Text(
              nome,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _GrupoObra extends StatelessWidget {
  const _GrupoObra({
    required this.itens,
    required this.onTap,
    required this.onRemover,
    required this.onReagendar,
    required this.onReplicar,
    required this.mostrarProduzir,
    required this.onMarcarProduzido,
  });

  final List<PlanejamentoItem> itens;
  final ValueChanged<PlanejamentoItem> onTap;
  final ValueChanged<PlanejamentoItem> onRemover;
  final ValueChanged<PlanejamentoItem> onReagendar;
  final ValueChanged<PlanejamentoItem> onReplicar;
  final bool mostrarProduzir;
  final VoidCallback onMarcarProduzido;

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
                if (mostrarProduzir && concluidos < itens.length)
                  TextButton.icon(
                    onPressed: onMarcarProduzido,
                    icon: const Icon(Icons.inventory_2_outlined, size: 16),
                    label: const Text('Produzir',
                        style: TextStyle(fontSize: 12)),
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
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
                onReagendar: () => onReagendar(item),
                onReplicar: () => onReplicar(item),
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
    required this.onReagendar,
    required this.onReplicar,
  });

  final PlanejamentoItem item;
  final VoidCallback onTap;
  final VoidCallback onRemover;
  final VoidCallback onReagendar;
  final VoidCallback onReplicar;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: item.obraPecaId != null ? onTap : null,
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
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, size: 20),
              onSelected: (v) {
                if (v == 'reagendar') onReagendar();
                if (v == 'replicar') onReplicar();
                if (v == 'remover') onRemover();
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'reagendar', child: Text('Reagendar')),
                PopupMenuItem(
                    value: 'replicar', child: Text('Replicar p/ outro dia')),
                PopupMenuItem(
                  value: 'remover',
                  child: Text('Remover',
                      style: TextStyle(color: AppColors.destructive)),
                ),
              ],
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
