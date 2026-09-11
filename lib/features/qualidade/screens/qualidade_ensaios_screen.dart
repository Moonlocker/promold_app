import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/auth_providers.dart';

import '../../../core/logic/qc_engine.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../models/qc.dart';
import '../../../providers/qualidade_providers.dart';
import '../../../providers/supabase_providers.dart';
import '../widgets/lote_form_sheet.dart';
import '../widgets/qc_padroes_sheet.dart';
import '../widgets/qualidade_badge.dart';
import 'lote_detalhe_screen.dart';

/// Lista de lotes de concreto.
class QualidadeEnsaiosScreen extends ConsumerStatefulWidget {
  const QualidadeEnsaiosScreen({super.key});

  @override
  ConsumerState<QualidadeEnsaiosScreen> createState() =>
      _QualidadeEnsaiosScreenState();
}

class _QualidadeEnsaiosScreenState
    extends ConsumerState<QualidadeEnsaiosScreen> {
  String _busca = '';

  @override
  Widget build(BuildContext context) {
    final lotesAsync = ref.watch(qcLotesProvider);
    final cpsAsync = ref.watch(qcCpsProvider);
    final ensaiosAsync = ref.watch(qcEnsaiosProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lotes de Concreto'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'PadrÃµes',
            onPressed: () => showQcPadroesSheet(context),
          ),
        ],
      ),
      floatingActionButton: ref.podeCriar('qualidade-ensaios')
          ? FloatingActionButton.extended(
              onPressed: () async {
                final ok = await showLoteFormSheet(context);
                if (ok == true) {
                  ref.invalidate(qcLotesProvider);
                  ref.invalidate(qcCpsProvider);
                }
              },
              icon: const Icon(Icons.add),
              label: const Text('Novo Lote'),
            )
          : null,
      body: lotesAsync.when(
        loading: () => const LoadingView(message: 'Carregando...'),
        error: (e, _) => Center(child: Text('Erro: $e')),
        data: (lotes) {
          final cps = cpsAsync.value ?? const <QcCorpoProva>[];
          final ensaios = ensaiosAsync.value ?? const <QcEnsaio>[];
          final status = calcularStatusLotes(
            lotes: lotes,
            cps: cps,
            ensaios: ensaios,
          );
          final filtrados = lotes.where((l) {
            final s = _busca.toLowerCase();
            return l.codigo.toLowerCase().contains(s) ||
                (l.fornecedor ?? '').toLowerCase().contains(s);
          }).toList();

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(qcLotesProvider);
              ref.invalidate(qcCpsProvider);
              ref.invalidate(qcEnsaiosProvider);
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
              children: [
                TextField(
                  onChanged: (v) => setState(() => _busca = v),
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search, size: 20),
                    hintText: 'Buscar por cÃ³digo ou fornecedor...',
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 12),
                if (filtrados.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 48),
                    child: EmptyState(
                      icon: Icons.science_outlined,
                      title: 'Nenhum lote encontrado',
                      message: 'Cadastre lotes de concreto e seus corpos de prova.',
                    ),
                  )
                else
                  ...filtrados.map((l) {
                    final nCps =
                        cps.where((c) => c.loteId == l.id).length;
                    final cpIds =
                        cps.where((c) => c.loteId == l.id).map((c) => c.id).toSet();
                    final nEns = ensaios
                        .where((e) => cpIds.contains(e.corpoProvaId))
                        .length;
                    return _LoteCard(
                      lote: l,
                      status: status[l.id] ?? QcStatus.aguardando,
                      nCps: nCps,
                      nEnsaios: nEns,
                      onChanged: () {
                        ref.invalidate(qcLotesProvider);
                        ref.invalidate(qcCpsProvider);
                        ref.invalidate(qcEnsaiosProvider);
                      },
                    );
                  }),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _LoteCard extends ConsumerWidget {
  const _LoteCard({
    required this.lote,
    required this.status,
    required this.nCps,
    required this.nEnsaios,
    required this.onChanged,
  });

  final QcLote lote;
  final QcStatus status;
  final int nCps;
  final int nEnsaios;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        onTap: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => LoteDetalheScreen(lote: lote),
            ),
          );
          onChanged();
        },
        title: Row(
          children: [
            Expanded(
              child: Text(lote.codigo,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
            QualidadeBadge(status: status),
          ],
        ),
        subtitle: Text(
          '${Formatters.dataBr(DateTime.tryParse(lote.dataConcretagem))} Â· '
          'FCK ${lote.fckMpa.toStringAsFixed(1)} MPa Â· $nCps CPs Â· $nEnsaios ensaios'
          '${(lote.fornecedor ?? '').isNotEmpty ? ' Â· ${lote.fornecedor}' : ''}',
          style: const TextStyle(fontSize: 12),
        ),
        trailing: (ref.podeEditar('qualidade-ensaios') ||
                ref.podeExcluir('qualidade-ensaios'))
            ? PopupMenuButton<String>(
          onSelected: (v) async {
            switch (v) {
              case 'editar':
                final ok = await showLoteFormSheet(context, lote: lote);
                if (ok == true) onChanged();
              case 'excluir':
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text('Excluir lote ${lote.codigo}?'),
                    content: const Text(
                        'Todos os corpos de prova e ensaios vinculados serÃ£o removidos.'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancelar'),
                      ),
                      FilledButton(
                        style: FilledButton.styleFrom(
                            backgroundColor: AppColors.destructive),
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Excluir'),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  await ref
                      .read(qualidadeRepositoryProvider)
                      .deleteLote(lote.id);
                  onChanged();
                }
            }
          },
          itemBuilder: (_) => [
            if (ref.podeEditar('qualidade-ensaios'))
              const PopupMenuItem(value: 'editar', child: Text('Editar')),
            if (ref.podeExcluir('qualidade-ensaios'))
              const PopupMenuItem(
                value: 'excluir',
                child: Text('Excluir',
                    style: TextStyle(color: AppColors.destructive)),
              ),
          ],
        )
            : null,
      ),
    );
  }
}
