import 'package:flutter/material.dart';

import '../../../core/logic/qc_engine.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../models/qc.dart';

/// Resultado consolidado de um lote de concreto: status por idade, estatísticas
/// e evolução da resistência com linha de referência do FCK.
///
/// Porte de `LoteResultadoDialog.tsx` do sistema web.
class LoteResultado extends StatelessWidget {
  const LoteResultado({
    super.key,
    required this.lote,
    required this.cps,
    required this.ensaios,
    required this.status,
  });

  final QcLote lote;
  final List<QcCorpoProva> cps;
  final List<QcEnsaio> ensaios;
  final QcStatus status;

  static const _ordem = ['inicial', '7d', '28d', 'livre'];
  static const _labels = {
    'inicial': 'Inicial (16h/1d)',
    '7d': '7 dias',
    '28d': '28 dias',
    'livre': 'Outros',
  };

  String _grupoDe(QcCorpoProva c) =>
      (c.grupo != null && c.grupo!.isNotEmpty)
          ? c.grupo!
          : inferGrupo(c.idadeRompimentoDias, c.idadeHoras).value;

  @override
  Widget build(BuildContext context) {
    final byCp = {for (final c in cps) c.id: c};

    final grupos = <String, _Grupo>{};
    for (final c in cps) {
      final g = _grupoDe(c);
      (grupos[g] ??= _Grupo()).cps++;
    }
    for (final e in ensaios) {
      final cp = byCp[e.corpoProvaId];
      if (cp == null) continue;
      final g = _grupoDe(cp);
      final grp = grupos[g] ??= _Grupo();
      final av = evaluateEnsaio(
        resistencia: e.resistenciaMpa,
        idadeDias: e.idadeRealDias ?? cp.idadeRompimentoDias,
        idadeHoras: cp.idadeHoras,
        grupo: QcGrupoX.fromValue(g),
        fck: lote.fckMpa,
        fcj: lote.fcjMpa,
      );
      grp.rompidos++;
      if (av.aprovado == true) grp.ok++;
      if (av.aprovado == false) grp.falhou++;
      grp.somaPct += av.pctFck;
      grp.n++;
    }

    final gruposPresentes = _ordem.where(grupos.containsKey).toList();

    // Estatísticas gerais.
    final vals = ensaios.map((e) => e.resistenciaMpa).toList();
    final media = vals.isEmpty
        ? 0.0
        : vals.reduce((a, b) => a + b) / vals.length;
    final maxV = vals.isEmpty ? 0.0 : vals.reduce((a, b) => a > b ? a : b);
    final minV = vals.isEmpty ? 0.0 : vals.reduce((a, b) => a < b ? a : b);

    final ens28 = ensaios.where((e) {
      final cp = byCp[e.corpoProvaId];
      final idade = e.idadeRealDias ?? cp?.idadeRompimentoDias ?? 0;
      return idade >= 28;
    }).toList();
    final aprovados28 =
        ens28.where((e) => e.resistenciaMpa >= lote.fckMpa).length;
    final atendimento =
        ens28.isEmpty ? 0.0 : (aprovados28 / ens28.length) * 100;

    final ordenados = [...ensaios]
      ..sort((a, b) => (a.dataEnsaio).compareTo(b.dataEnsaio));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (gruposPresentes.isNotEmpty) ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('STATUS GERAL POR IDADE',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                          color: AppColors.mutedForeground)),
                  const SizedBox(height: 10),
                  for (final g in gruposPresentes)
                    _grupoLinha(g, grupos[g]!),
                  if (lote.fcjMpa != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'FCJ de liberação: ${lote.fcjMpa} MPa · '
                        'FCK de projeto: ${lote.fckMpa} MPa',
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.mutedForeground),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _stat('Ensaios', '${vals.length}'),
            _stat('Média (MPa)', vals.isEmpty ? '—' : media.toStringAsFixed(1)),
            _stat('Maior (MPa)', vals.isEmpty ? '—' : maxV.toStringAsFixed(1),
                cor: AppColors.success),
            _stat('Menor (MPa)', vals.isEmpty ? '—' : minV.toStringAsFixed(1),
                cor: AppColors.warning),
            _stat('FCK Projeto', '${lote.fckMpa.toStringAsFixed(0)} MPa'),
            _stat('Atendimento 28d', '${atendimento.toStringAsFixed(0)}%',
                cor: atendimento >= 100
                    ? AppColors.success
                    : atendimento > 0
                        ? AppColors.warning
                        : AppColors.destructive),
            _stat('Situação', status.label,
                cor: status == QcStatus.aprovado
                    ? AppColors.success
                    : status == QcStatus.reprovado
                        ? AppColors.destructive
                        : AppColors.warning),
            _stat('Corpos de prova', '${cps.length}'),
          ],
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: const [
                    Icon(Icons.trending_up, size: 18, color: AppColors.primary),
                    SizedBox(width: 8),
                    Text('Evolução da resistência',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                  ],
                ),
                const SizedBox(height: 12),
                if (ordenados.isEmpty)
                  const SizedBox(
                    height: 180,
                    child: Center(
                      child: Text('Sem ensaios registrados.',
                          style:
                              TextStyle(color: AppColors.mutedForeground)),
                    ),
                  )
                else
                  SizedBox(
                    height: 220,
                    child: CustomPaint(
                      size: Size.infinite,
                      painter: _LineChartPainter(
                        values: ordenados.map((e) => e.resistenciaMpa).toList(),
                        labels: ordenados
                            .map((e) => Formatters.dataBr(
                                DateTime.tryParse(e.dataEnsaio)))
                            .toList(),
                        fck: lote.fckMpa,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _grupoLinha(String g, _Grupo grp) {
    final completo = grp.rompidos >= grp.cps;
    final IconData icone;
    final Color cor;
    if (grp.falhou > 0) {
      icone = Icons.warning_amber_outlined;
      cor = AppColors.destructive;
    } else if (completo && grp.ok > 0) {
      icone = Icons.check_circle_outline;
      cor = AppColors.success;
    } else {
      icone = Icons.schedule;
      cor = AppColors.warning;
    }
    final pct = grp.n > 0 ? grp.somaPct / grp.n : null;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icone, size: 18, color: cor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(_labels[g] ?? g,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600)),
          ),
          Text(
            '${grp.rompidos}/${grp.cps} rompidos'
            '${pct != null ? ' · ${pct.toStringAsFixed(0)}% do FCK' : ''}',
            style: const TextStyle(
                fontSize: 11.5, color: AppColors.mutedForeground),
          ),
          const SizedBox(width: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(grp.cps, (i) {
              final rompido = i < grp.rompidos;
              Color c;
              if (!rompido) {
                c = AppColors.border;
              } else if (i < grp.ok) {
                c = AppColors.success;
              } else if (grp.falhou > 0 && i >= grp.ok) {
                c = AppColors.destructive;
              } else {
                c = AppColors.warning;
              }
              return Container(
                width: 10,
                height: 10,
                margin: const EdgeInsets.only(left: 3),
                decoration: BoxDecoration(color: c, shape: BoxShape.circle),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _stat(String label, String valor, {Color? cor}) {
    return SizedBox(
      width: 108,
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label.toUpperCase(),
                  style: const TextStyle(
                      fontSize: 9.5,
                      letterSpacing: 0.4,
                      color: AppColors.mutedForeground)),
              const SizedBox(height: 4),
              Text(
                valor,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: cor ?? AppColors.foreground,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Grupo {
  int cps = 0;
  int rompidos = 0;
  int ok = 0;
  int falhou = 0;
  int n = 0;
  double somaPct = 0;
}

class _LineChartPainter extends CustomPainter {
  _LineChartPainter({
    required this.values,
    required this.labels,
    required this.fck,
  });

  final List<double> values;
  final List<String> labels;
  final double fck;

  @override
  void paint(Canvas canvas, Size size) {
    const padLeft = 34.0;
    const padRight = 8.0;
    const padTop = 10.0;
    const padBottom = 22.0;
    final w = size.width - padLeft - padRight;
    final h = size.height - padTop - padBottom;
    if (w <= 0 || h <= 0 || values.isEmpty) return;

    var maxV = values.reduce((a, b) => a > b ? a : b);
    maxV = maxV < fck ? fck : maxV;
    maxV = (maxV * 1.15) + 1;

    double x(int i) =>
        padLeft + (values.length == 1 ? w / 2 : (w * i / (values.length - 1)));
    double y(double v) => padTop + h - (v / maxV) * h;

    final axis = Paint()
      ..color = AppColors.border
      ..strokeWidth = 1;
    // Eixos
    canvas.drawLine(Offset(padLeft, padTop), Offset(padLeft, padTop + h), axis);
    canvas.drawLine(Offset(padLeft, padTop + h),
        Offset(padLeft + w, padTop + h), axis);

    // Grade + rótulos Y
    final grid = Paint()
      ..color = AppColors.border.withValues(alpha: 0.5)
      ..strokeWidth = 0.6;
    final txt = TextPainter(textDirection: TextDirection.ltr);
    for (var i = 0; i <= 4; i++) {
      final v = maxV * i / 4;
      final yy = y(v);
      canvas.drawLine(Offset(padLeft, yy), Offset(padLeft + w, yy), grid);
      txt.text = TextSpan(
        text: v.toStringAsFixed(0),
        style: const TextStyle(fontSize: 9, color: AppColors.mutedForeground),
      );
      txt.layout();
      txt.paint(canvas, Offset(2, yy - txt.height / 2));
    }

    // Linha de referência do FCK
    if (fck > 0) {
      final yf = y(fck);
      final dash = Paint()
        ..color = AppColors.destructive
        ..strokeWidth = 1.4;
      var xx = padLeft;
      while (xx < padLeft + w) {
        canvas.drawLine(Offset(xx, yf),
            Offset((xx + 6).clamp(padLeft, padLeft + w), yf), dash);
        xx += 12;
      }
      txt.text = TextSpan(
        text: 'FCK ${fck.toStringAsFixed(0)}',
        style: const TextStyle(fontSize: 9, color: AppColors.destructive),
      );
      txt.layout();
      txt.paint(canvas, Offset(padLeft + w - txt.width - 2, yf - txt.height - 2));
    }

    // Linha de dados
    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final p = Offset(x(i), y(values[i]));
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = AppColors.primary
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2,
    );

    // Pontos + valores
    final dot = Paint()..color = AppColors.primary;
    for (var i = 0; i < values.length; i++) {
      final p = Offset(x(i), y(values[i]));
      canvas.drawCircle(p, 3.5, dot);
      if (values.length <= 8) {
        txt.text = TextSpan(
          text: values[i].toStringAsFixed(0),
          style: const TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: AppColors.foreground),
        );
        txt.layout();
        txt.paint(canvas, Offset(p.dx - txt.width / 2, p.dy - txt.height - 4));
      }
      // Rótulo X (data) — apenas primeiro, último e intermediários.
      final mostrar = values.length <= 6 ||
          i == 0 ||
          i == values.length - 1 ||
          i == values.length ~/ 2;
      if (mostrar && i < labels.length) {
        final d = labels[i];
        final curto = d.length >= 5 ? d.substring(0, 5) : d;
        txt.text = TextSpan(
          text: curto,
          style:
              const TextStyle(fontSize: 8.5, color: AppColors.mutedForeground),
        );
        txt.layout();
        txt.paint(canvas, Offset(p.dx - txt.width / 2, padTop + h + 4));
      }
    }
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter old) =>
      old.values != values || old.fck != fck;
}
