import 'package:flutter/material.dart';

import '../../../core/logic/peca_calc.dart';
import '../../../core/logic/status_config.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../models/obra.dart';
import '../../../models/obra_peca.dart';
import '../../../services/obra_relatorio_service.dart';

/// Resumo consolidado da obra (porte resumido de `ResumoObraModal`).
Future<void> showResumoObraSheet(
  BuildContext context, {
  required Obra obra,
  required List<ObraPeca> pecas,
  Map<String, dynamic>? insumosResumo,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _ResumoObraSheet(
      obra: obra,
      pecas: pecas,
      insumosResumo: insumosResumo,
    ),
  );
}

class _ResumoObraSheet extends StatelessWidget {
  const _ResumoObraSheet({
    required this.obra,
    required this.pecas,
    this.insumosResumo,
  });

  final Obra obra;
  final List<ObraPeca> pecas;
  final Map<String, dynamic>? insumosResumo;

  static const _densidade = 2400.0;

  @override
  Widget build(BuildContext context) {
    final contagem = <String, int>{};
    var volume = 0.0, aco = 0.0, peso = 0.0;
    for (final p in pecas) {
      final key = normalizarStatus(p.status);
      contagem[key] = (contagem[key] ?? 0) + 1;
      final v = calcularPeca(p).volume;
      volume += v;
      aco += v * (p.kgAcoPorMetro ?? 0).toDouble();
      peso += v * _densidade;
    }
    final progresso = pecas.isEmpty
        ? 0
        : (pecas.fold<double>(0, (a, p) => a + statusWeight(p.status)) /
                pecas.length)
            .round();

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, controller) => ListView(
        controller: controller,
        padding: EdgeInsets.fromLTRB(
            20, 12, 20, 24 + MediaQuery.of(context).padding.bottom),
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(obra.nome,
              style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w700)),
          Text('${obra.cliente}'
              '${obra.endereco != null ? ' · ${obra.endereco}' : ''}',
              style: const TextStyle(
                  fontSize: 12.5, color: AppColors.mutedForeground)),
          const SizedBox(height: 4),
          Text(
            'Status: ${obra.status}'
            '${obra.dataInicio != null ? ' · Início: ${Formatters.dataBr(obra.dataInicio)}' : ''}'
            '${obra.dataPrevisao != null ? ' · Previsão: ${Formatters.dataBr(obra.dataPrevisao)}' : ''}',
            style: const TextStyle(
                fontSize: 12, color: AppColors.mutedForeground),
          ),
          const SizedBox(height: 14),
          _kpiGrid([
            ['Progresso', '$progresso%'],
            ['Total de peças', '${pecas.length}'],
            ['Volume', '${volume.toStringAsFixed(2)} m³'],
            ['Aço', '${aco.toStringAsFixed(0)} kg'],
            ['Peso', '${peso.toStringAsFixed(0)} kg'],
            [
              'Valor da obra',
              obra.valorObra != null
                  ? 'R\$ ${Formatters.numero(obra.valorObra, 2)}'
                  : '—'
            ],
          ]),
          const SizedBox(height: 18),
          const Text('Peças por status',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          ...statusOrdem.map((s) {
            final n = contagem[s] ?? 0;
            final total = pecas.isEmpty ? 1 : pecas.length;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(statusLabel(s),
                            style: const TextStyle(fontSize: 12.5)),
                      ),
                      Text('$n',
                          style: const TextStyle(
                              fontSize: 12.5, fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(height: 3),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: n / total,
                      minHeight: 6,
                      backgroundColor: AppColors.muted,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: () => ObraRelatorioService.gerar(
              obra: obra,
              pecas: pecas,
              insumosResumo: insumosResumo,
            ),
            icon: const Icon(Icons.picture_as_pdf_outlined),
            label: const Text('Gerar PDF do resumo'),
          ),
        ],
      ),
    );
  }

  Widget _kpiGrid(List<List<String>> itens) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 2.3,
      children: itens
          .map((it) => Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.muted,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(it[0],
                        style: const TextStyle(
                            fontSize: 10.5, color: AppColors.mutedForeground)),
                    const SizedBox(height: 3),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(it[1],
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
              ))
          .toList(),
    );
  }
}
