import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../models/obra_peca.dart';
import '../../../providers/obra_providers.dart';

/// Uma peça posicionada no espaço 3D (caixa alinhada aos eixos).
class _Box3 {
  _Box3({
    required this.center,
    required this.half,
    required this.color,
    required this.peca,
  });

  final _Vec3 center;
  final _Vec3 half;
  final Color color;
  final ObraPeca peca;
}

class _Vec3 {
  const _Vec3(this.x, this.y, this.z);
  final double x;
  final double y;
  final double z;

  _Vec3 operator +(_Vec3 o) => _Vec3(x + o.x, y + o.y, z + o.z);
  _Vec3 operator *(double s) => _Vec3(x * s, y * s, z * s);
}

/// Visualizador 3D nativo das peças da obra.
///
/// Não depende de arquivos IFC: distribui as peças em um pátio virtual e
/// permite girar (arrastar), aproximar (pinça) e tocar para selecionar.
class Obra3DViewer extends StatefulWidget {
  const Obra3DViewer({
    super.key,
    required this.pecas,
    required this.statusConfig,
    this.onSelect,
    this.selectedId,
  });

  final List<ObraPeca> pecas;
  final StatusConfig statusConfig;
  final ValueChanged<ObraPeca?>? onSelect;
  final String? selectedId;

  @override
  State<Obra3DViewer> createState() => _Obra3DViewerState();
}

class _Obra3DViewerState extends State<Obra3DViewer> {
  double _yaw = -0.7;
  double _pitch = 0.55;
  double _zoom = 1;
  Offset _pan = Offset.zero;
  Offset _lastFocal = Offset.zero;
  double _lastScale = 1;

  List<_Box3> _boxes = [];
  double _sceneRadius = 1;

  @override
  void initState() {
    super.initState();
    _buildScene();
  }

  @override
  void didUpdateWidget(covariant Obra3DViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pecas != widget.pecas) _buildScene();
  }

  double _dim(num? v, num? fallback, double def) =>
      (v ?? fallback ?? def).toDouble();

  void _buildScene() {
    final pecas = widget.pecas;
    final boxes = <_Box3>[];
    if (pecas.isEmpty) {
      _boxes = boxes;
      return;
    }

    // Dimensões em metros.
    double comp(ObraPeca p) => _dim(p.comprimento,
        p.pecaCatalogo?.comprimentoPadrao, 6).clamp(0.5, 40);
    double larg(ObraPeca p) =>
        _dim(p.largura, p.pecaCatalogo?.larguraPadrao, 0.4).clamp(0.2, 5);
    double alt(ObraPeca p) =>
        _dim(p.altura, p.pecaCatalogo?.alturaPadrao, 0.4).clamp(0.2, 5);

    var maxLen = 0.0;
    for (final p in pecas) {
      maxLen = math.max(maxLen, comp(p));
    }
    final cols = math.max(1, (math.sqrt(pecas.length)).ceil());
    final gap = math.max(0.6, maxLen * 0.15);

    // Largura da célula = maior comprimento + gap.
    final cellX = maxLen + gap;
    final cellZ = 2.2;

    for (var i = 0; i < pecas.length; i++) {
      final p = pecas[i];
      final c = comp(p), l = larg(p), a = alt(p);
      final col = i % cols;
      final row = i ~/ cols;
      final cx = col * cellX;
      final cz = row * cellZ;
      boxes.add(_Box3(
        center: _Vec3(cx, a / 2, cz),
        half: _Vec3(c / 2, a / 2, l / 2),
        color: widget.statusConfig.colorOf(p.status),
        peca: p,
      ));
    }

    // Raio aproximado para enquadramento.
    var maxX = 0.0, maxZ = 0.0;
    for (final b in boxes) {
      maxX = math.max(maxX, b.center.x + b.half.x);
      maxZ = math.max(maxZ, b.center.z + b.half.z);
    }
    _sceneRadius = math.max(math.max(maxX, maxZ), 1);
    _boxes = boxes;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.pecas.isEmpty) {
      return const Center(
        child: Text('Nenhuma peça para exibir.',
            style: TextStyle(color: AppColors.mutedForeground)),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        return GestureDetector(
          onScaleStart: (d) {
            _lastFocal = d.localFocalPoint;
            _lastScale = 1;
          },
          onScaleUpdate: (d) {
            setState(() {
              if (d.pointerCount >= 2) {
                _zoom = (_zoom * (d.scale / _lastScale)).clamp(0.2, 12);
                _lastScale = d.scale;
                final delta = d.localFocalPoint - _lastFocal;
                _pan += delta;
                _lastFocal = d.localFocalPoint;
              } else {
                final delta = d.focalPointDelta;
                _yaw += delta.dx * 0.01;
                _pitch = (_pitch + delta.dy * 0.01).clamp(-1.5, 1.5);
              }
            });
          },
          onTapUp: (d) => _handleTap(d.localPosition, size),
          child: ClipRect(
            child: CustomPaint(
              size: size,
              painter: _Obra3DPainter(
                boxes: _boxes,
                yaw: _yaw,
                pitch: _pitch,
                zoom: _zoom,
                pan: _pan,
                sceneRadius: _sceneRadius,
                selectedId: widget.selectedId,
              ),
            ),
          ),
        );
      },
    );
  }

  void _handleTap(Offset tap, Size size) {
    final camera = _Camera(
      yaw: _yaw,
      pitch: _pitch,
      zoom: _zoom,
      pan: _pan,
      size: size,
      sceneRadius: _sceneRadius,
    );
    ObraPeca? best;
    var bestDepth = double.infinity;
    var bestDist = 44.0;
    for (final b in _boxes) {
      final proj = camera.project(b.center);
      final d = (proj.offset - tap).distance;
      if (d < bestDist && proj.depth < bestDepth) {
        best = b.peca;
        bestDepth = proj.depth;
        bestDist = d;
      }
    }
    widget.onSelect?.call(best);
  }
}

class _Projected {
  const _Projected(this.offset, this.depth);
  final Offset offset;
  final double depth;
}

class _Camera {
  _Camera({
    required this.yaw,
    required this.pitch,
    required this.zoom,
    required this.pan,
    required this.size,
    required this.sceneRadius,
  });

  final double yaw;
  final double pitch;
  final double zoom;
  final Offset pan;
  final Size size;
  final double sceneRadius;

  double get _scale {
    final base = math.min(size.width, size.height) / (sceneRadius * 2.6);
    return base * zoom;
  }

  Offset _center() => Offset(size.width / 2, size.height / 2 + size.height * 0.06);

  _Projected project(_Vec3 p) {
    final cy = math.cos(yaw), sy = math.sin(yaw);
    final x1 = p.x * cy - p.z * sy;
    final z1 = p.x * sy + p.z * cy;
    final cp = math.cos(pitch), sp = math.sin(pitch);
    final y2 = p.y * cp - z1 * sp;
    final z2 = p.y * sp + z1 * cp;
    final s = _scale;
    final c = _center();
    return _Projected(
      Offset(x1 * s + c.dx + pan.dx, -y2 * s + c.dy + pan.dy),
      z2,
    );
  }

  _Vec3 rotate(_Vec3 p) {
    final cy = math.cos(yaw), sy = math.sin(yaw);
    final x1 = p.x * cy - p.z * sy;
    final z1 = p.x * sy + p.z * cy;
    final cp = math.cos(pitch), sp = math.sin(pitch);
    final y2 = p.y * cp - z1 * sp;
    final z2 = p.y * sp + z1 * cp;
    return _Vec3(x1, y2, z2);
  }

  Offset projectVec(_Vec3 rotated) {
    final s = _scale;
    final c = _center();
    return Offset(
      rotated.x * s + c.dx + pan.dx,
      -rotated.y * s + c.dy + pan.dy,
    );
  }
}

class _Face {
  const _Face(this.points, this.depth, this.shade, this.color, this.selected);
  final List<Offset> points;
  final double depth;
  final double shade;
  final Color color;
  final bool selected;
}

class _Obra3DPainter extends CustomPainter {
  _Obra3DPainter({
    required this.boxes,
    required this.yaw,
    required this.pitch,
    required this.zoom,
    required this.pan,
    required this.sceneRadius,
    required this.selectedId,
  });

  final List<_Box3> boxes;
  final double yaw;
  final double pitch;
  final double zoom;
  final Offset pan;
  final double sceneRadius;
  final String? selectedId;

  static const _lightDir = _Vec3(-0.4, 0.85, 0.35);

  @override
  void paint(Canvas canvas, Size size) {
    final camera = _Camera(
      yaw: yaw,
      pitch: pitch,
      zoom: zoom,
      pan: pan,
      size: size,
      sceneRadius: sceneRadius,
    );

    // Fundo com grade no plano do chão.
    _paintGround(canvas, camera, size);

    final faces = <_Face>[];
    for (final b in boxes) {
      final selected = b.peca.id == selectedId;
      final corners = _corners(b);
      final rotated = corners.map(camera.rotate).toList();
      final projected = rotated.map(camera.projectVec).toList();

      // 6 faces: índices dos 8 cantos.
      const faceIdx = [
        [0, 1, 2, 3], // topo (y+)
        [4, 5, 6, 7], // base (y-)
        [0, 1, 5, 4], // frente z-
        [2, 3, 7, 6], // trás z+
        [1, 2, 6, 5], // direita x+
        [0, 3, 7, 4], // esquerda x-
      ];
      final normals = [
        _Vec3(0, 1, 0),
        _Vec3(0, -1, 0),
        _Vec3(0, 0, -1),
        _Vec3(0, 0, 1),
        _Vec3(1, 0, 0),
        _Vec3(-1, 0, 0),
      ];

      for (var f = 0; f < faceIdx.length; f++) {
        final idx = faceIdx[f];
        final pts = idx.map((i) => projected[i]).toList();
        final depth = idx
                .map((i) => rotated[i].z)
                .reduce((a, b2) => a + b2) /
            idx.length;
        final n = camera.rotate(normals[f]);
        final dot = (n.x * _lightDir.x + n.y * _lightDir.y + n.z * _lightDir.z);
        final shade = (0.45 + 0.55 * dot.abs()).clamp(0.35, 1.0);
        faces.add(_Face(pts, depth, shade, b.color, selected));
      }
    }

    // Pintor: faces mais distantes primeiro.
    faces.sort((a, b) => a.depth.compareTo(b.depth));

    final paint = Paint()..style = PaintingStyle.fill;
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..color = Colors.black.withValues(alpha: 0.25);

    for (final face in faces) {
      final path = Path()..moveTo(face.points.first.dx, face.points.first.dy);
      for (var i = 1; i < face.points.length; i++) {
        path.lineTo(face.points[i].dx, face.points[i].dy);
      }
      path.close();
      final hsl = HSLColor.fromColor(face.color);
      final shaded = hsl
          .withLightness((hsl.lightness * face.shade).clamp(0.12, 0.85))
          .toColor();
      paint.color = shaded;
      canvas.drawPath(path, paint);
      if (face.selected) {
        canvas.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.4
            ..color = AppColors.accent,
        );
      } else {
        canvas.drawPath(path, stroke);
      }
    }
  }

  List<_Vec3> _corners(_Box3 b) {
    final c = b.center, h = b.half;
    return [
      _Vec3(c.x - h.x, c.y + h.y, c.z - h.z),
      _Vec3(c.x + h.x, c.y + h.y, c.z - h.z),
      _Vec3(c.x + h.x, c.y + h.y, c.z + h.z),
      _Vec3(c.x - h.x, c.y + h.y, c.z + h.z),
      _Vec3(c.x - h.x, c.y - h.y, c.z - h.z),
      _Vec3(c.x + h.x, c.y - h.y, c.z - h.z),
      _Vec3(c.x + h.x, c.y - h.y, c.z + h.z),
      _Vec3(c.x - h.x, c.y - h.y, c.z + h.z),
    ];
  }

  void _paintGround(Canvas canvas, _Camera camera, Size size) {
    final bg = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFE7ECF3), Color(0xFFD3DAE5)],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, bg);

    final gridPaint = Paint()
      ..color = const Color(0xFF9AA3AD).withValues(alpha: 0.35)
      ..strokeWidth = 0.7;
    final n = 24;
    final step = (sceneRadius * 2.2) / n;
    for (var i = -n; i <= n; i++) {
      final a = camera.projectVec(camera.rotate(_Vec3(i * step, 0, -n * step)));
      final b = camera.projectVec(camera.rotate(_Vec3(i * step, 0, n * step)));
      canvas.drawLine(a, b, gridPaint);
      final c = camera.projectVec(camera.rotate(_Vec3(-n * step, 0, i * step)));
      final d = camera.projectVec(camera.rotate(_Vec3(n * step, 0, i * step)));
      canvas.drawLine(c, d, gridPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _Obra3DPainter old) =>
      old.yaw != yaw ||
      old.pitch != pitch ||
      old.zoom != zoom ||
      old.pan != pan ||
      old.boxes != boxes ||
      old.selectedId != selectedId;
}
