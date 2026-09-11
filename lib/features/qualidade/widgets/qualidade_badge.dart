import 'package:flutter/material.dart';

import '../../../core/logic/qc_engine.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/qc.dart';

/// Chip de status de qualidade (Aprovado/Reprovado/Aguardando).
class QualidadeBadge extends StatelessWidget {
  const QualidadeBadge({super.key, required this.status});

  final QcStatus status;

  @override
  Widget build(BuildContext context) {
    final (cor, label) = switch (status) {
      QcStatus.aprovado => (AppColors.success, 'Aprovado'),
      QcStatus.reprovado => (AppColors.destructive, 'Reprovado'),
      QcStatus.aguardando => (AppColors.warning, 'Aguardando'),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
            fontSize: 11, fontWeight: FontWeight.w600, color: cor),
      ),
    );
  }
}

/// Calcula o mapa `loteId -> status`.
Map<String, QcStatus> calcularStatusLotes({
  required List<QcLote> lotes,
  required List<QcCorpoProva> cps,
  required List<QcEnsaio> ensaios,
}) {
  final cpByLote = <String, List<QcCorpoProva>>{};
  final cpIdToLote = <String, String>{};
  for (final c in cps) {
    cpByLote.putIfAbsent(c.loteId, () => []).add(c);
    cpIdToLote[c.id] = c.loteId;
  }
  final ensByLote = <String, List<QcEnsaio>>{};
  for (final e in ensaios) {
    final lid = cpIdToLote[e.corpoProvaId];
    if (lid == null) continue;
    ensByLote.putIfAbsent(lid, () => []).add(e);
  }
  final map = <String, QcStatus>{};
  for (final l in lotes) {
    map[l.id] = computeLoteStatus(
      l.fckMpa,
      ensByLote[l.id] ?? const [],
      cpByLote[l.id] ?? const [],
      fcj: l.fcjMpa,
    );
  }
  return map;
}
