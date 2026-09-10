import 'package:flutter/material.dart';

import '../../../core/logic/producao_calc.dart';
import '../../../core/logic/status_config.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/producao_indicadores.dart';

/// Tabela "Progresso por Obra": contagem exata de peças em cada status.
class ObraProgressTable extends StatelessWidget {
  const ObraProgressTable({
    super.key,
    required this.rows,
    required this.colors,
    this.onObraTap,
  });

  final List<ObraProgresso> rows;
  final Map<String, Color> colors;
  final ValueChanged<String>? onObraTap;

  static const _obraWidth = 170.0;
  static const _totalWidth = 52.0;
  static const _statusWidth = 76.0;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _header(),
          const Divider(height: 1),
          for (final row in rows) ...[_linha(row), const Divider(height: 1)],
        ],
      ),
    );
  }

  Widget _header() {
    return Container(
      color: AppColors.muted,
      child: Row(
        children: [
          const SizedBox(
            width: _obraWidth,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Text(
                'Obra',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(
            width: _totalWidth,
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Total',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
              ),
            ),
          ),
          for (final status in producaoStatusOrdem)
            SizedBox(
              width: _statusWidth,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: statusColor(status, colors),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      statusLabel(status),
                      style: const TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _linha(ObraProgresso row) {
    return InkWell(
      onTap: onObraTap == null ? null : () => onObraTap!(row.obraId),
      child: Row(
        children: [
          SizedBox(
            width: _obraWidth,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  if (row.cor != null) ...[
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: hexToColor(row.cor) ?? AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                  Expanded(
                    child: Text(
                      row.nome,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(
            width: _totalWidth,
            child: Text(
              '${row.total}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: AppColors.mutedForeground,
              ),
            ),
          ),
          for (final status in producaoStatusOrdem)
            SizedBox(width: _statusWidth, child: _celulaStatus(row, status)),
        ],
      ),
    );
  }

  Widget _celulaStatus(ObraProgresso row, String status) {
    final count = row.counts[status] ?? 0;
    final cor = statusColor(status, colors);
    final pct = row.total > 0 ? count / row.total : 0.0;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Column(
        children: [
          Text(
            '$count',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: count > 0 ? cor : AppColors.mutedForeground,
            ),
          ),
          if (count > 0) ...[
            const SizedBox(height: 3),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: pct,
                minHeight: 4,
                backgroundColor: AppColors.muted,
                valueColor: AlwaysStoppedAnimation<Color>(cor),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
