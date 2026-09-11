import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/logic/qc_engine.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../models/qc.dart';
import '../../../providers/qualidade_providers.dart';
import '../../../providers/supabase_providers.dart';
import '../widgets/ensaio_form_sheet.dart';
import '../widgets/qualidade_badge.dart';

/// Detalhe de um lote: corpos de prova e ensaios.
class LoteDetalheScreen extends ConsumerWidget {
  const LoteDetalheScreen({super.key, required this.lote});

  final QcLote lote;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cpsAsync = ref.watch(qcCpsLoteProvider(lote.id));
    final ensaiosAsync = ref.watch(qcEnsaiosLoteProvider(lote.id));

    final cps = cpsAsync.value ?? const <QcCorpoProva>[];
    final ensaios = ensaiosAsync.value ?? const <QcEnsaio>[];
    final status = computeLoteStatus(
      lote.fckMpa,
      ensaios,
      cps,
      fcj: lote.fcjMpa,
    );

    return Scaffold(
      appBar: AppBar(title: Text('Lote ${lote.codigo}')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: cps.isEmpty
            ? null
            : () async {
                final ok = await showEnsaioFormSheet(
                  context,
                  lote: lote,
                  cps: cps,
                );
                if (ok == true) {
                  ref.invalidate(qcEnsaiosLoteProvider(lote.id));
                  ref.invalidate(qcEnsaiosProvider);
                }
              },
        icon: const Icon(Icons.add),
        label: const Text('Novo Ensaio'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(qcCpsLoteProvider(lote.id));
          ref.invalidate(qcEnsaiosLoteProvider(lote.id));
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(lote.codigo,
                              style: const TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.w700)),
                        ),
                        QualidadeBadge(status: status),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Concretagem: ${Formatters.dataBr(DateTime.tryParse(lote.dataConcretagem))}',
                      style: const TextStyle(fontSize: 12.5),
                    ),
                    Text('FCK: ${lote.fckMpa.toStringAsFixed(1)} MPa'
                        '${lote.fcjMpa != null ? ' · FCJ: ${lote.fcjMpa!.toStringAsFixed(1)} MPa' : ''}',
                        style: const TextStyle(fontSize: 12.5)),
                    if ((lote.fornecedor ?? '').isNotEmpty)
                      Text('Fornecedor: ${lote.fornecedor}',
                          style: const TextStyle(fontSize: 12.5)),
                    if (lote.volumeM3 != null)
                      Text('Volume: ${lote.volumeM3} m³',
                          style: const TextStyle(fontSize: 12.5)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Corpos de prova',
                style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            if (cpsAsync.isLoading)
              const LoadingView()
            else if (cps.isEmpty)
              const Text('Nenhum CP cadastrado',
                  style: TextStyle(color: AppColors.mutedForeground))
            else
              ...cps.map((c) {
                final ensaiosCp =
                    ensaios.where((e) => e.corpoProvaId == c.id).toList();
                final ultimo = ensaiosCp.isNotEmpty ? ensaiosCp.first : null;
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    dense: true,
                    title: Text(c.identificador),
                    subtitle: Text(
                      'Moldagem ${Formatters.dataBr(DateTime.tryParse(c.dataMoldagem))} · ${formatIdade(c.idadeRompimentoDias, c.idadeHoras)}'
                      '${c.grupo != null ? ' · ${c.grupo}' : ''}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    trailing: ultimo != null
                        ? Text(
                            '${ultimo.resistenciaMpa.toStringAsFixed(1)} MPa',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: (ultimo.aprovado ?? false)
                                  ? AppColors.success
                                  : AppColors.foreground,
                            ),
                          )
                        : const Text('—',
                            style: TextStyle(
                                color: AppColors.mutedForeground)),
                  ),
                );
              }),
            const SizedBox(height: 16),
            const Text('Ensaios',
                style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            if (ensaiosAsync.isLoading)
              const LoadingView()
            else if (ensaios.isEmpty)
              const Text('Nenhum ensaio registrado',
                  style: TextStyle(color: AppColors.mutedForeground))
            else
              ...ensaios.map((e) {
                final cp =
                    cps.where((c) => c.id == e.corpoProvaId).firstOrNull;
                final ok = e.resistenciaMpa >= lote.fckMpa;
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    dense: true,
                    onTap: () async {
                      final result = await showEnsaioFormSheet(
                        context,
                        lote: lote,
                        cps: cps,
                        ensaio: e,
                      );
                      if (result == true) {
                        ref.invalidate(qcEnsaiosLoteProvider(lote.id));
                        ref.invalidate(qcEnsaiosProvider);
                      }
                    },
                    title: Text(
                        '${cp?.identificador ?? 'CP'} · ${e.resistenciaMpa.toStringAsFixed(1)} MPa'),
                    subtitle: Text(
                      '${Formatters.dataBr(DateTime.tryParse(e.dataEnsaio))}'
                      '${e.laboratorio != null ? ' · ${e.laboratorio}' : ''}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: (ok
                                    ? AppColors.success
                                    : AppColors.destructive)
                                .withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            ok ? 'Aprovado' : 'Reprovado',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: ok
                                  ? AppColors.success
                                  : AppColors.destructive,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline,
                              size: 18, color: AppColors.destructive),
                          onPressed: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Excluir ensaio'),
                                content: const Text('Deseja excluir este ensaio?'),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, false),
                                    child: const Text('Cancelar'),
                                  ),
                                  FilledButton(
                                    style: FilledButton.styleFrom(
                                        backgroundColor:
                                            AppColors.destructive),
                                    onPressed: () =>
                                        Navigator.pop(context, true),
                                    child: const Text('Excluir'),
                                  ),
                                ],
                              ),
                            );
                            if (confirm == true) {
                              await ref
                                  .read(qualidadeRepositoryProvider)
                                  .deleteEnsaio(e.id);
                              ref.invalidate(qcEnsaiosLoteProvider(lote.id));
                              ref.invalidate(qcEnsaiosProvider);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}
