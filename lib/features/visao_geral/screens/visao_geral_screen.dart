import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/logic/status_config.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../models/categoria_peca.dart';
import '../../../models/obra.dart';
import '../../../models/obra_peca.dart';
import '../../../providers/auth_providers.dart';
import '../../../providers/obra_providers.dart';
import 'processos_etapas_screen.dart';

const _statusLabel = {
  'planejamento': 'Planejamento',
  'ativa': 'Ativa',
  'pausada': 'Pausada',
  'concluida': 'Concluída',
};

const _statusCor = {
  'planejamento': AppColors.info,
  'ativa': AppColors.success,
  'pausada': AppColors.warning,
  'concluida': AppColors.mutedForeground,
};

/// Status Geral: KPIs e matriz de progresso por categoria e obra.
class VisaoGeralScreen extends ConsumerStatefulWidget {
  const VisaoGeralScreen({super.key});

  @override
  ConsumerState<VisaoGeralScreen> createState() => _VisaoGeralScreenState();
}

class _VisaoGeralScreenState extends ConsumerState<VisaoGeralScreen> {
  String _status = 'todos';

  @override
  Widget build(BuildContext context) {
    final obrasAsync = ref.watch(obrasListProvider);
    final pecas = ref.watch(todasPecasResumoProvider).value ?? const [];
    final categorias = ref.watch(categoriasPecaProvider).value ?? const [];
    final statusCfg =
        ref.watch(statusConfigProvider).value ?? StatusConfig.defaults;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Status Geral'),
        actions: [
          IconButton(
            tooltip: 'Processos e Etapas',
            icon: const Icon(Icons.account_tree_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const ProcessosEtapasScreen(),
              ),
            ),
          ),
        ],
      ),
      body: obrasAsync.when(
        loading: () => const LoadingView(),
        error: (e, _) => Center(child: Text('Erro: $e')),
        data: (obrasTodas) {
          final obras = obrasTodas
              .where((o) => _status == 'todos' || o.status == _status)
              .toList();
          final obraIds = obras.map((o) => o.id).toSet();
          final pecasFiltradas =
              pecas.where((p) => obraIds.contains(p.obraId)).toList();

          final hoje = Formatters.hojeBr();
          final progresso = pecasFiltradas.isEmpty
              ? 0
              : (pecasFiltradas
                          .fold<double>(0,
                              (a, p) => a + statusCfg.weightOf(p.status)) /
                      pecasFiltradas.length)
                  .round();
          final concluidas = pecasFiltradas
              .where((p) => statusCfg.weightOf(p.status) >= 100)
              .length;
          final producaoHoje = pecasFiltradas
              .where((p) => p.dataConcretagem != null &&
                  Formatters.iso(p.dataConcretagem!) == hoje)
              .length;
          final atrasadas = obras.where((o) {
            if (o.dataPrevisao == null) return false;
            final totalO =
                pecas.where((p) => p.obraId == o.id).length;
            final montO = pecas
                .where((p) =>
                    p.obraId == o.id &&
                    statusCfg.weightOf(p.status) >= 100)
                .length;
            final pct = totalO == 0 ? 0.0 : montO / totalO;
            return o.dataPrevisao!
                    .isBefore(DateTime.now()) &&
                pct < 1;
          }).length;

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(obrasListProvider);
              ref.invalidate(todasPecasResumoProvider);
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _Kpi(
                        label: 'Progresso',
                        valor: '$progresso%',
                        cor: AppColors.success,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _Kpi(
                        label: 'Concluído',
                        valor: '$concluidas/${pecasFiltradas.length}',
                        cor: AppColors.info,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _Kpi(
                        label: 'Produção hoje',
                        valor: '$producaoHoje',
                        cor: AppColors.warning,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _Kpi(
                        label: 'Atraso',
                        valor: '$atrasadas',
                        cor: atrasadas > 0
                            ? AppColors.destructive
                            : AppColors.mutedForeground,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _status,
                  isDense: true,
                  decoration:
                      const InputDecoration(labelText: 'Status', isDense: true),
                  items: const [
                    DropdownMenuItem(value: 'todos', child: Text('Todos')),
                    DropdownMenuItem(
                        value: 'planejamento', child: Text('Planejamento')),
                    DropdownMenuItem(value: 'ativa', child: Text('Ativa')),
                    DropdownMenuItem(value: 'pausada', child: Text('Pausada')),
                    DropdownMenuItem(
                        value: 'concluida', child: Text('Concluída')),
                  ],
                  onChanged: (v) => setState(() => _status = v ?? 'todos'),
                ),
                const SizedBox(height: 16),
                if (obras.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 48),
                    child: EmptyState(
                      icon: Icons.visibility_outlined,
                      title: 'Nenhuma obra encontrada',
                    ),
                  )
                else ...[
                  _Matriz(
                    obras: obras,
                    pecas: pecasFiltradas,
                    categorias: categorias,
                    statusCfg: statusCfg,
                    onObraTap: (id) =>
                        context.push(AppRoutes.obraDetalhe(id)),
                  ),
                  const SizedBox(height: 16),
                  const Text('Obras',
                      style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  ...obras.map((o) => _ObraResumo(obra: o)),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Matriz extends StatelessWidget {
  const _Matriz({
    required this.obras,
    required this.pecas,
    required this.categorias,
    required this.statusCfg,
    required this.onObraTap,
  });

  final List<Obra> obras;
  final List<ObraPeca> pecas;
  final List<CategoriaPeca> categorias;
  final StatusConfig statusCfg;
  final ValueChanged<String> onObraTap;

  static const _cellW = 84.0;
  static const _labelW = 130.0;

  @override
  Widget build(BuildContext context) {
    final linhas = <(String?, String)>[
      for (final c in categorias) (c.id, c.nome),
      (null, 'Sem categoria'),
    ];

    double progressoDe(String? catId, String obraId) {
      final lista = pecas.where((p) {
        if (p.obraId != obraId) return false;
        final cid = p.pecaCatalogo?.categoriaId;
        return catId == null ? cid == null : cid == catId;
      }).toList();
      if (lista.isEmpty) return -1;
      return lista
              .fold<double>(0, (a, p) => a + statusCfg.weightOf(p.status)) /
          lista.length;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text('Matriz de progresso',
                  style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700)),
            ),
            const SizedBox(height: 2),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text('Categoria × obra (% concluído)',
                  style: TextStyle(
                      fontSize: 11.5, color: AppColors.mutedForeground)),
            ),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Cabeçalho de obras
                  Row(
                    children: [
                      const SizedBox(width: _labelW),
                      for (final o in obras)
                        SizedBox(
                          width: _cellW,
                          child: InkWell(
                            onTap: () => onObraTap(o.id),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 4, vertical: 4),
                              child: Column(
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: o.cor != null
                                          ? hexToColor(o.cor)
                                          : AppColors.primary,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    o.nome,
                                    maxLines: 2,
                                    textAlign: TextAlign.center,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const Divider(height: 1),
                  for (final linha in linhas) ...[
                    Row(
                      children: [
                        SizedBox(
                          width: _labelW,
                          child: Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 14),
                            child: Text(
                              linha.$2,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.w500),
                            ),
                          ),
                        ),
                        for (final o in obras)
                          SizedBox(
                            width: _cellW,
                            child: _celula(progressoDe(linha.$1, o.id)),
                          ),
                      ],
                    ),
                    const Divider(height: 1),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _celula(double pct) {
    if (pct < 0) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 10),
        child: Center(
          child: Text('—',
              style: TextStyle(color: AppColors.mutedForeground, fontSize: 12)),
        ),
      );
    }
    final cor = pct >= 99
        ? AppColors.success
        : pct >= 50
            ? AppColors.warning
            : AppColors.destructive;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: cor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: cor.withValues(alpha: 0.4)),
        ),
        child: Center(
          child: Text('${pct.round()}%',
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w700, color: cor)),
        ),
      ),
    );
  }
}

class _Kpi extends StatelessWidget {
  const _Kpi({required this.label, required this.valor, required this.cor});

  final String label;
  final String valor;
  final Color cor;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Column(
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(valor,
                  style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w700, color: cor)),
            ),
            const SizedBox(height: 2),
            Text(label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 10.5, color: AppColors.mutedForeground)),
          ],
        ),
      ),
    );
  }
}

class _ObraResumo extends StatelessWidget {
  const _ObraResumo({required this.obra});

  final Obra obra;

  @override
  Widget build(BuildContext context) {
    final cor = _statusCor[obra.status] ?? AppColors.primary;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        onTap: () => context.push(AppRoutes.obraDetalhe(obra.id)),
        title: Text(obra.nome,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          '${obra.cliente}'
          '${obra.dataPrevisao != null ? ' · Previsão ${Formatters.dataBr(obra.dataPrevisao)}' : ''}',
          style: const TextStyle(fontSize: 12.5),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: cor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            _statusLabel[obra.status] ?? obra.status,
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w600, color: cor),
          ),
        ),
      ),
    );
  }
}
