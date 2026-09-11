import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/logic/qc_engine.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../models/qc.dart';
import '../../../providers/qualidade_providers.dart';
import '../widgets/qualidade_badge.dart';

/// Rastreabilidade: por peça (qual lote) e por lote (quais peças).
class QualidadeRastreabilidadeScreen extends StatelessWidget {
  const QualidadeRastreabilidadeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Rastreabilidade'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Por Peça'),
              Tab(text: 'Por Lote'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _PorPecaTab(),
            _PorLoteTab(),
          ],
        ),
      ),
    );
  }
}

class _PorPecaTab extends ConsumerStatefulWidget {
  const _PorPecaTab();

  @override
  ConsumerState<_PorPecaTab> createState() => _PorPecaTabState();
}

class _PorPecaTabState extends ConsumerState<_PorPecaTab> {
  final _termo = TextEditingController();
  String _busca = '';

  @override
  void dispose() {
    _termo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lotes = ref.watch(qcLotesProvider).value ?? const <QcLote>[];
    final cps = ref.watch(qcCpsProvider).value ?? const <QcCorpoProva>[];
    final ensaios = ref.watch(qcEnsaiosProvider).value ?? const <QcEnsaio>[];
    final status = calcularStatusLotes(lotes: lotes, cps: cps, ensaios: ensaios);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        TextField(
          controller: _termo,
          onChanged: (v) => setState(() => _busca = v.trim()),
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search, size: 20),
            hintText: 'Identificador da peça (ex: P-001)',
            isDense: true,
          ),
        ),
        const SizedBox(height: 12),
        if (_busca.length < 2)
          const Padding(
            padding: EdgeInsets.only(top: 40),
            child: Text(
              'Digite ao menos 2 caracteres para buscar.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.mutedForeground),
            ),
          )
        else
          Consumer(
            builder: (context, ref, _) {
              final async = ref.watch(qcBuscarPecasProvider(_busca));
              return async.when(
                loading: () => const LoadingView(),
                error: (e, _) => Text('Erro: $e'),
                data: (pecas) {
                  if (pecas.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.only(top: 40),
                      child: Text('Nenhuma peça encontrada.',
                          textAlign: TextAlign.center,
                          style:
                              TextStyle(color: AppColors.mutedForeground)),
                    );
                  }
                  return Column(
                    children: pecas.map((p) {
                      final loteId = p['qc_lote_id'] as String?;
                      final loteRel = p['qc_lotes_concreto'];
                      final codigo = loteRel is Map
                          ? loteRel['codigo'] as String?
                          : null;
                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: ListTile(
                          title: Text(p['identificador'] as String? ?? '-'),
                          subtitle: Text(
                            '${_obraNome(p)} · Lote ${codigo ?? 'sem lote'}',
                            style: const TextStyle(fontSize: 12.5),
                          ),
                          trailing: loteId != null
                              ? QualidadeBadge(
                                  status: status[loteId] ??
                                      QcStatus.aguardando,
                                )
                              : const Text('—'),
                        ),
                      );
                    }).toList(),
                  );
                },
              );
            },
          ),
      ],
    );
  }

  String _obraNome(Map<String, dynamic> p) {
    final obra = p['obras'];
    if (obra is Map && obra['nome'] is String) return obra['nome'] as String;
    return '—';
  }
}

class _PorLoteTab extends ConsumerStatefulWidget {
  const _PorLoteTab();

  @override
  ConsumerState<_PorLoteTab> createState() => _PorLoteTabState();
}

class _PorLoteTabState extends ConsumerState<_PorLoteTab> {
  String? _loteId;

  @override
  Widget build(BuildContext context) {
    final lotes = ref.watch(qcLotesProvider).value ?? const <QcLote>[];
    final lote = lotes.where((l) => l.id == _loteId).firstOrNull;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        DropdownButtonFormField<String>(
          initialValue: _loteId,
          isExpanded: true,
          decoration: const InputDecoration(
              labelText: 'Selecione um lote', isDense: true),
          items: lotes
              .map((l) => DropdownMenuItem(
                    value: l.id,
                    child: Text('${l.codigo} · ${l.fckMpa.toStringAsFixed(1)} MPa',
                        overflow: TextOverflow.ellipsis),
                  ))
              .toList(),
          onChanged: (v) => setState(() => _loteId = v),
        ),
        const SizedBox(height: 16),
        if (lote != null) ...[
          Text(
            'Lote ${lote.codigo} · FCK ${lote.fckMpa.toStringAsFixed(1)} MPa · '
            '${Formatters.dataBr(DateTime.tryParse(lote.dataConcretagem))}',
            style: const TextStyle(fontSize: 12.5),
          ),
          const SizedBox(height: 12),
          Consumer(
            builder: (context, ref, _) {
              final async = ref.watch(qcPecasPorLoteProvider(lote.id));
              return async.when(
                loading: () => const LoadingView(),
                error: (e, _) => Text('Erro: $e'),
                data: (pecas) {
                  if (pecas.isEmpty) {
                    return const Text(
                      'Nenhuma peça vinculada a este lote ainda.',
                      style: TextStyle(color: AppColors.mutedForeground),
                    );
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Peças produzidas (${pecas.length})',
                          style:
                              const TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 8),
                      ...pecas.map((p) => Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              dense: true,
                              title: Text(p['identificador'] as String? ?? '-'),
                              subtitle: Text(_obraNome(p),
                                  style: const TextStyle(fontSize: 12)),
                              trailing: Text(p['status'] as String? ?? '',
                                  style: const TextStyle(fontSize: 12)),
                            ),
                          )),
                    ],
                  );
                },
              );
            },
          ),
        ],
      ],
    );
  }

  String _obraNome(Map<String, dynamic> p) {
    final obra = p['obras'];
    if (obra is Map && obra['nome'] is String) return obra['nome'] as String;
    return '—';
  }
}
