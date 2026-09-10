import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Badge de status, com as mesmas cores usadas no webapp.
class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.status});

  final String status;

  static const Map<String, (String, Color)> _config = {
    'ativa': ('Ativa', AppColors.success),
    'pausada': ('Pausada', AppColors.warning),
    'planejamento': ('Planejamento', AppColors.info),
    'concluida': ('Concluída', AppColors.mutedForeground),
  };

  @override
  Widget build(BuildContext context) {
    final (label, color) =
        _config[status] ?? (status, AppColors.mutedForeground);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
