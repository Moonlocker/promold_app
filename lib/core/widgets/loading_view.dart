import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Indicador de carregamento centralizado, no padrão visual do Promold.
class LoadingView extends StatelessWidget {
  const LoadingView({super.key, this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 36,
            height: 36,
            child: CircularProgressIndicator(strokeWidth: 3),
          ),
          if (message != null) ...[
            const SizedBox(height: 16),
            Text(
              message!,
              style: const TextStyle(color: AppColors.mutedForeground),
            ),
          ],
        ],
      ),
    );
  }
}
