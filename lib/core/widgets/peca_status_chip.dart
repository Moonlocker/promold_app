import 'package:flutter/material.dart';

import '../logic/status_config.dart';

/// Chip de status de peça, colorido conforme a configuração da organização.
class PecaStatusChip extends StatelessWidget {
  const PecaStatusChip({
    super.key,
    required this.status,
    this.colors,
    this.compact = false,
  });

  final String status;
  final Map<String, Color>? colors;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final color = statusColor(status, colors);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 9,
        vertical: compact ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        statusLabel(status),
        style: TextStyle(
          fontSize: compact ? 10 : 11.5,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
