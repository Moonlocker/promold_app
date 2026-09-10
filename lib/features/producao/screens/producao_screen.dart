import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/logic/peca_calc.dart';
import '../../../core/logic/status_config.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/multi_select_sheet.dart';
import '../../../core/widgets/stat_card.dart';
import '../../../models/obra_peca.dart';
import '../../../models/producao_indicadores.dart';
import '../../../providers/auth_providers.dart';
import '../../../providers/obra_providers.dart';
import '../../../providers/producao_providers.dart';
import '../widgets/obra_progress_table.dart';
import '../widgets/producao_chart.dart';

/// Indicadores de produção (módulo `indicadores` no webapp).
class ProducaoScreen extends ConsumerWidget {
  const ProducaoScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final indicadoresAsync = ref.watch(producaoIndicadoresProvider);
    final filtros = ref.watch(producaoFiltrosProvider);
    final cores =
        ref.watch(statusConfigProvider).value?.colors ?? defaultStatusColors;
    final obras = ref.watch(obrasListProvider).value ?? const [];
    final obrasNome = {for (final o in obras) o.id: o.nome};

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Indicadores'),
            Text(
              '${Formatters.dataBr(filtros.inicio)} — '
              '${Formatters.dataBr(filtros.fim)}',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: AppColors.mutedForeground,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          const _FiltrosBar(),
          Expanded(
            child: indicadoresAsync.when(
              loading: () =>
                  const LoadingView(message: 'Carregando indicadores...'),
              error: (error, _) => ErrorView(
                message: error.toString(),
                onRetry: () => ref.invalidate(producaoIndicadoresProvider),
              ),
              data: (data) => RefreshIndicator(
                onRefresh: () async =>
                    ref.invalidate(producaoIndicadoresProvider),
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _Cards(
                      data: data,
                      onCard: (chave) =>
                          _abrirCard(context, data, obrasNome, chave),
                    ),
                    const SizedBox(height: 16),
                    _GraficoCard(
                      data: data,
                      onDayTap: (dia) =>
                          _abrirDia(context, data, obrasNome, dia),
                    ),
                    if (data.porTipo.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _ResumoPorTipo(porTipo: data.porTipo),
                    ],
                    if (data.obrasProgresso.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _MatrizCard(
                        data: data,
                        cores: cores,
                        onObraTap: (id) =>
                            context.push(AppRoutes.obraDetalhe(id)),
                      ),
                    ],
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// --------------------------------------------------------------- Filtros

class _FiltrosBar extends ConsumerWidget {
  const _FiltrosBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filtros = ref.watch(producaoFiltrosProvider);
    final obras = ref.watch(obrasFiltroOptionsProvider);
    final categorias = ref.watch(categoriasPecaProvider).value ?? const [];
    final pecas = ref.watch(pecasFiltroOptionsProvider);

    return Container(
      color: AppColors.card,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            ActionChip(
              avatar: const Icon(Icons.calendar_today_outlined, size: 15),
              label: Text(
                '${Formatters.dataBr(filtros.inicio)} - '
                '${Formatters.dataBr(filtros.fim)}',
                style: const TextStyle(fontSize: 12),
              ),
              onPressed: () => _abrirPeriodo(context, ref),
            ),
            const SizedBox(width: 8),
            ActionChip(
              avatar: const Icon(Icons.business_outlined, size: 15),
              label: Text(
                filtros.obras.isEmpty
                    ? 'Obras'
                    : 'Obras (${filtros.obras.length})',
                style: const TextStyle(fontSize: 12),
              ),
              backgroundColor: filtros.obras.isEmpty
                  ? null
                  : AppColors.primary.withValues(alpha: 0.12),
              onPressed: () async {
                final res = await showMultiSelectSheet(
                  context: context,
                  title: 'Filtrar por obra',
                  selected: filtros.obras,
                  searchPlaceholder: 'Buscar obra...',
                  options: [
                    for (final o in obras) MultiSelectOption(o.id, o.nome),
                  ],
                );
                if (res != null) {
                  ref.read(producaoFiltrosProvider.notifier).setObras(res);
                }
              },
            ),
            const SizedBox(width: 8),
            ActionChip(
              avatar: const Icon(Icons.category_outlined, size: 15),
              label: Text(
                filtros.categorias.isEmpty
                    ? 'Categorias'
                    : 'Categorias (${filtros.categorias.length})',
                style: const TextStyle(fontSize: 12),
              ),
              backgroundColor: filtros.categorias.isEmpty
                  ? null
                  : AppColors.primary.withValues(alpha: 0.12),
              onPressed: () async {
                final res = await showMultiSelectSheet(
                  context: context,
                  title: 'Filtrar por categoria',
                  selected: filtros.categorias,
                  searchPlaceholder: 'Buscar categoria...',
                  options: [
                    for (final c in categorias) MultiSelectOption(c.id, c.nome),
                  ],
                );
                if (res != null) {
                  ref.read(producaoFiltrosProvider.notifier).setCategorias(res);
                }
              },
            ),
            const SizedBox(width: 8),
            ActionChip(
              avatar: const Icon(Icons.extension_outlined, size: 15),
              label: Text(
                filtros.pecas.isEmpty
                    ? 'Peças'
                    : 'Peças (${filtros.pecas.length})',
                style: const TextStyle(fontSize: 12),
              ),
              backgroundColor: filtros.pecas.isEmpty
                  ? null
                  : AppColors.primary.withValues(alpha: 0.12),
              onPressed: () async {
                final res = await showMultiSelectSheet(
                  context: context,
                  title: 'Filtrar por peça',
                  selected: filtros.pecas,
                  searchPlaceholder: 'Buscar peça...',
                  options: [
                    for (final p in pecas) MultiSelectOption(p.id, p.nome),
                  ],
                );
                if (res != null) {
                  ref.read(producaoFiltrosProvider.notifier).setPecas(res);
                }
              },
            ),
            if (filtros.temFiltros) ...[
              const SizedBox(width: 8),
              ActionChip(
                avatar: const Icon(Icons.filter_alt_off_outlined, size: 15),
                label: const Text('Limpar', style: TextStyle(fontSize: 12)),
                onPressed: () =>
                    ref.read(producaoFiltrosProvider.notifier).limparFiltros(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _abrirPeriodo(BuildContext context, WidgetRef ref) async {
    final agora = DateTime.now();
    final hoje = DateTime(agora.year, agora.month, agora.day);
    final escolha = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Período',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.calendar_view_month),
              title: const Text('Este mês'),
              onTap: () => Navigator.pop(context, 'mes'),
            ),
            ListTile(
              leading: const Icon(Icons.looks_one_outlined),
              title: const Text('Últimos 7 dias'),
              onTap: () => Navigator.pop(context, '7'),
            ),
            ListTile(
              leading: const Icon(Icons.looks_3_outlined),
              title: const Text('Últimos 30 dias'),
              onTap: () => Navigator.pop(context, '30'),
            ),
            ListTile(
              leading: const Icon(Icons.date_range_outlined),
              title: const Text('Personalizado...'),
              onTap: () => Navigator.pop(context, 'custom'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (escolha == null) return;
    if (!context.mounted) return;
    final notifier = ref.read(producaoFiltrosProvider.notifier);
    switch (escolha) {
      case 'mes':
        notifier.setPeriodo(DateTime(agora.year, agora.month, 1), hoje);
      case '7':
        notifier.setPeriodo(hoje.subtract(const Duration(days: 6)), hoje);
      case '30':
        notifier.setPeriodo(hoje.subtract(const Duration(days: 29)), hoje);
      case 'custom':
        final range = await showDateRangePicker(
          context: context,
          firstDate: DateTime(2020),
          lastDate: DateTime(agora.year + 2),
          initialDateRange: DateTimeRange(
            start: ref.read(producaoFiltrosProvider).inicio,
            end: ref.read(producaoFiltrosProvider).fim,
          ),
          locale: const Locale('pt', 'BR'),
        );
        if (range != null) {
          notifier.setPeriodo(range.start, range.end);
        }
    }
  }
}

// ----------------------------------------------------------------- Cards

typedef _CardKey = String;

class _Cards extends StatelessWidget {
  const _Cards({required this.data, required this.onCard});

  final ProducaoIndicadores data;
  final ValueChanged<_CardKey> onCard;

  @override
  Widget build(BuildContext context) {
    final cards = <Widget>[
      StatCard(
        title: 'Peças Produzidas',
        value: Formatters.numero(data.totalPeriodo),
        subtitle: 'no período',
        icon: Icons.inventory_2_outlined,
        color: AppColors.success,
        onTap: () => onCard('pecas'),
      ),
      StatCard(
        title: 'Média Diária',
        value: Formatters.numero(data.mediaDiaria),
        subtitle: 'peças/dia',
        icon: Icons.trending_up,
        color: AppColors.primary,
        onTap: () => onCard('media'),
      ),
      StatCard(
        title: 'Dias com Produção',
        value: Formatters.numero(data.diasComProducao),
        subtitle: 'dias',
        icon: Icons.calendar_month_outlined,
        color: AppColors.mutedForeground,
        onTap: () => onCard('dias'),
      ),
      StatCard(
        title: 'Concreto',
        value: '${Formatters.numero(data.volumeConcreto, 2)} m³',
        subtitle: 'volume',
        icon: Icons.water_drop_outlined,
        color: AppColors.info,
        onTap: () => onCard('concreto'),
      ),
      StatCard(
        title: 'Aço Consumido',
        value: '${Formatters.numero(data.acoTotal, 1)} kg',
        subtitle: 'no período',
        icon: Icons.hardware_outlined,
        color: AppColors.warning,
        onTap: () => onCard('aco'),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = (constraints.maxWidth - 12) / 2;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [for (final c in cards) SizedBox(width: w, child: c)],
        );
      },
    );
  }
}

class _GraficoCard extends StatelessWidget {
  const _GraficoCard({required this.data, required this.onDayTap});

  final ProducaoIndicadores data;
  final ValueChanged<ProducaoDia> onDayTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Produção Diária',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 2),
            const Text(
              'Produzido x planejado · toque numa coluna para detalhar',
              style: TextStyle(
                fontSize: 11.5,
                color: AppColors.mutedForeground,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: const [
                _Legenda(cor: AppColors.success, texto: 'Produzido'),
                SizedBox(width: 14),
                _Legenda(cor: AppColors.primary, texto: 'Planejado'),
              ],
            ),
            const SizedBox(height: 8),
            ProducaoDiariaChart(dias: data.chartDiario, onDayTap: onDayTap),
          ],
        ),
      ),
    );
  }
}

class _Legenda extends StatelessWidget {
  const _Legenda({required this.cor, required this.texto});

  final Color cor;
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: cor, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(texto, style: const TextStyle(fontSize: 11.5)),
      ],
    );
  }
}

class _ResumoPorTipo extends StatelessWidget {
  const _ResumoPorTipo({required this.porTipo});

  final List<MapEntry<String, int>> porTipo;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Resumo por Tipo de Peça',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final t in porTipo)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.secondary,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '${t.key}  ${t.value}',
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MatrizCard extends StatelessWidget {
  const _MatrizCard({
    required this.data,
    required this.cores,
    required this.onObraTap,
  });

  final ProducaoIndicadores data;
  final Map<String, Color> cores;
  final ValueChanged<String> onObraTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Progresso por Obra',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(height: 2),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Quantidade exata de peças em cada status',
                style: TextStyle(
                  fontSize: 11.5,
                  color: AppColors.mutedForeground,
                ),
              ),
            ),
            const SizedBox(height: 12),
            ObraProgressTable(
              rows: data.obrasProgresso,
              colors: cores,
              onObraTap: onObraTap,
            ),
          ],
        ),
      ),
    );
  }
}

// -------------------------------------------------------------- Detalhes

Future<void> _abrirCard(
  BuildContext context,
  ProducaoIndicadores data,
  Map<String, String> obrasNome,
  String chave,
) {
  switch (chave) {
    case 'media':
      return _mostrarSheet(
        context,
        title: 'Como a Média Diária é calculada',
        child: _MediaDetalhe(data: data),
      );
    case 'dias':
      return _mostrarSheet(
        context,
        title: 'Dias com produção',
        child: _DiasLista(
          data: data,
          onDiaTap: (dia) => _abrirDia(context, data, obrasNome, dia),
        ),
      );
    case 'concreto':
    case 'aco':
    case 'pecas':
    default:
      return _mostrarSheet(
        context,
        title: chave == 'aco'
            ? 'Consumo de Aço'
            : chave == 'concreto'
            ? 'Consumo de Concreto'
            : 'Peças produzidas no período',
        child: _PecasLista(
          registros: data.registros,
          obrasNome: obrasNome,
          modo: chave,
        ),
      );
  }
}

void _abrirDia(
  BuildContext context,
  ProducaoIndicadores data,
  Map<String, String> obrasNome,
  ProducaoDia dia,
) {
  final registros = data.registros
      .where((r) => _iso(r.dataConcretagem) == dia.date)
      .toList();
  _mostrarSheet(
    context,
    title: 'Peças de ${dia.label}',
    child: _PecasLista(
      registros: registros,
      obrasNome: obrasNome,
      modo: 'pecas',
    ),
  );
}

String _iso(DateTime? d) {
  if (d == null) return '';
  return '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

Future<void> _mostrarSheet(
  BuildContext context, {
  required String title,
  required Widget child,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => SizedBox(
      height: MediaQuery.of(context).size.height * 0.78,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                  tooltip: 'Fechar',
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(child: child),
        ],
      ),
    ),
  );
}

class _PecasLista extends StatelessWidget {
  const _PecasLista({
    required this.registros,
    required this.obrasNome,
    required this.modo,
  });

  final List<ObraPeca> registros;
  final Map<String, String> obrasNome;
  final String modo;

  @override
  Widget build(BuildContext context) {
    if (registros.isEmpty) {
      return const Center(
        child: Text(
          'Nenhuma peça no período.',
          style: TextStyle(color: AppColors.mutedForeground),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: registros.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final r = registros[i];
        final calc = calcularPeca(r);
        final obra = obrasNome[r.obraId];
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (r.identificador.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.muted,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        r.identificador,
                        style: const TextStyle(
                          fontSize: 11,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      r.pecaCatalogo?.nome ?? 'Peça',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              if (obra != null) ...[
                const SizedBox(height: 4),
                Text(
                  obra,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: AppColors.mutedForeground,
                  ),
                ),
              ],
              const SizedBox(height: 6),
              Wrap(
                spacing: 12,
                children: [
                  _Info(
                    label: modo == 'aco' ? 'Aço' : 'Volume',
                    valor: modo == 'aco'
                        ? '${Formatters.numero(calc.aco, 2)} kg'
                        : '${Formatters.numero(calc.volume, 3)} m³',
                  ),
                  _Info(
                    label: 'Peso',
                    valor: '${Formatters.numero(calc.peso, 0)} kg',
                  ),
                  _Info(
                    label: 'Aço',
                    valor: '${Formatters.numero(calc.aco, 1)} kg',
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Info extends StatelessWidget {
  const _Info({required this.label, required this.valor});

  final String label;
  final String valor;

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        style: const TextStyle(
          fontSize: 11.5,
          color: AppColors.mutedForeground,
        ),
        children: [
          TextSpan(text: '$label: '),
          TextSpan(
            text: valor,
            style: const TextStyle(
              color: AppColors.foreground,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _DiasLista extends StatelessWidget {
  const _DiasLista({required this.data, required this.onDiaTap});

  final ProducaoIndicadores data;
  final ValueChanged<ProducaoDia> onDiaTap;

  @override
  Widget build(BuildContext context) {
    final dias = data.chartDiario.where((d) => d.pecas > 0).toList();
    if (dias.isEmpty) {
      return const Center(
        child: Text(
          'Nenhuma produção no período.',
          style: TextStyle(color: AppColors.mutedForeground),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: dias.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final d = dias[i];
        return ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(d.label),
          subtitle: Text(
            '${Formatters.numero(d.concreto, 2)} m³ · '
            '${Formatters.numero(d.aco, 1)} kg',
            style: const TextStyle(fontSize: 12),
          ),
          trailing: Text(
            '${d.pecas} peça(s)',
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: AppColors.success,
            ),
          ),
          onTap: () {
            Navigator.pop(context);
            onDiaTap(d);
          },
        );
      },
    );
  }
}

class _MediaDetalhe extends StatelessWidget {
  const _MediaDetalhe({required this.data});

  final ProducaoIndicadores data;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.muted,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Fórmula',
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.mutedForeground,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${data.totalPeriodo} peças ÷ ${data.diasComProducao} dias '
                'com produção = ${data.mediaDiaria} peças/dia',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Apenas dias em que houve pelo menos 1 peça concretada são '
          'contados.',
          style: TextStyle(color: AppColors.mutedForeground, fontSize: 12.5),
        ),
      ],
    );
  }
}
