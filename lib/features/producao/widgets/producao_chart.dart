import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../models/producao_indicadores.dart';

/// Gráfico de produção diária: barras (produzido) + linha tracejada
/// (planejado). Tocar numa coluna dispara [onDayTap].
class ProducaoDiariaChart extends StatelessWidget {
  const ProducaoDiariaChart({
    super.key,
    required this.dias,
    this.corProduzido = AppColors.success,
    this.corPlanejado = AppColors.primary,
    this.onDayTap,
    this.height = 200,
  });

  final List<ProducaoDia> dias;
  final Color corProduzido;
  final Color corPlanejado;
  final ValueChanged<ProducaoDia>? onDayTap;
  final double height;

  static const _leftPad = 30.0;
  static const _rightPad = 8.0;
  static const _topPad = 10.0;
  static const _bottomPad = 22.0;

  @override
  Widget build(BuildContext context) {
    if (dias.isEmpty) {
      return SizedBox(
        height: height,
        child: const Center(
          child: Text(
            'Sem dados no período.',
            style: TextStyle(color: AppColors.mutedForeground),
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: onDayTap == null
              ? null
              : (details) {
                  final plotWidth = width - _leftPad - _rightPad;
                  if (plotWidth <= 0) return;
                  final n = dias.length;
                  final idx =
                      ((details.localPosition.dx - _leftPad) / plotWidth * n)
                          .floor()
                          .clamp(0, n - 1);
                  onDayTap!(dias[idx]);
                },
          child: CustomPaint(
            size: Size(width, height),
            painter: _ProducaoChartPainter(
              dias: dias,
              corProduzido: corProduzido,
              corPlanejado: corPlanejado,
              leftPad: _leftPad,
              rightPad: _rightPad,
              topPad: _topPad,
              bottomPad: _bottomPad,
            ),
          ),
        );
      },
    );
  }
}

class _ProducaoChartPainter extends CustomPainter {
  _ProducaoChartPainter({
    required this.dias,
    required this.corProduzido,
    required this.corPlanejado,
    required this.leftPad,
    required this.rightPad,
    required this.topPad,
    required this.bottomPad,
  });

  final List<ProducaoDia> dias;
  final Color corProduzido;
  final Color corPlanejado;
  final double leftPad;
  final double rightPad;
  final double topPad;
  final double bottomPad;

  @override
  void paint(Canvas canvas, Size size) {
    final n = dias.length;
    final plotWidth = size.width - leftPad - rightPad;
    final plotHeight = size.height - topPad - bottomPad;
    if (plotWidth <= 0 || plotHeight <= 0 || n == 0) return;

    var maxVal = 1;
    for (final d in dias) {
      maxVal = math.max(maxVal, math.max(d.pecas, d.planejado));
    }

    final gridPaint = Paint()
      ..color = AppColors.border
      ..strokeWidth = 1;
    const gridLines = 3;
    for (var i = 0; i <= gridLines; i++) {
      final y = topPad + plotHeight * (i / gridLines);
      canvas.drawLine(
        Offset(leftPad, y),
        Offset(size.width - rightPad, y),
        gridPaint,
      );
      final valor = (maxVal * (1 - i / gridLines)).round();
      _text(
        canvas,
        '$valor',
        Offset(0, y - 6),
        color: AppColors.mutedForeground,
        size: 9,
      );
    }

    final slot = plotWidth / n;
    final barWidth = math.max(2.0, slot * 0.6);
    final barPaint = Paint()..color = corProduzido;

    // Barras (produzido)
    for (var i = 0; i < n; i++) {
      final d = dias[i];
      if (d.pecas <= 0) continue;
      final h = plotHeight * (d.pecas / maxVal);
      final cx = leftPad + slot * i + slot / 2;
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(cx - barWidth / 2, topPad + plotHeight - h, barWidth, h),
        const Radius.circular(3),
      );
      canvas.drawRRect(rect, barPaint);
    }

    // Linha (planejado)
    final linePaint = Paint()
      ..color = corPlanejado
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final path = Path();
    for (var i = 0; i < n; i++) {
      final d = dias[i];
      final x = leftPad + slot * i + slot / 2;
      final y = topPad + plotHeight * (1 - d.planejado / maxVal);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    _drawDashed(canvas, path, linePaint);

    // Rótulos do eixo X (a cada k colunas)
    final passo = (n / 6).ceil().clamp(1, n);
    for (var i = 0; i < n; i++) {
      if (i % passo != 0 && i != n - 1) continue;
      final x = leftPad + slot * i + slot / 2;
      _text(
        canvas,
        dias[i].label,
        Offset(x - 14, size.height - bottomPad + 4),
        color: AppColors.mutedForeground,
        size: 9,
        width: 28,
        align: TextAlign.center,
      );
    }
  }

  void _drawDashed(Canvas canvas, Path path, Paint paint) {
    const dash = 6.0;
    const gap = 4.0;
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = math.min(distance + dash, metric.length);
        canvas.drawPath(metric.extractPath(distance, next), paint);
        distance = next + gap;
      }
    }
  }

  void _text(
    Canvas canvas,
    String text,
    Offset offset, {
    required Color color,
    required double size,
    double? width,
    TextAlign align = TextAlign.left,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(color: color, fontSize: size),
      ),
      textAlign: align,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: width ?? double.infinity);
    tp.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant _ProducaoChartPainter old) =>
      old.dias != dias ||
      old.corProduzido != corProduzido ||
      old.corPlanejado != corPlanejado;
}
