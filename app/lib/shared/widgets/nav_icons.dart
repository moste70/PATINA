import 'dart:math' as math;
import 'package:flutter/material.dart';

// ── ProjectsIcon ─────────────────────────────────────────────────────────────

class ProjectsIcon extends StatelessWidget {
  final Color color;
  final double size;
  const ProjectsIcon({super.key, required this.color, this.size = 24});

  @override
  Widget build(BuildContext context) => CustomPaint(
        size: Size(size, size),
        painter: _ProjectsPainter(color),
      );
}

class _ProjectsPainter extends CustomPainter {
  final Color color;
  _ProjectsPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.055
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final g = size.width * 0.135;
    final gap = size.width * 0.075;
    final total = g * 2 * 2 + gap;
    final ox = (size.width - total) / 2;
    final oy = (size.height - total) / 2;
    final cut = g * 0.55;

    for (var col = 0; col < 2; col++) {
      for (var row = 0; row < 2; row++) {
        final x = ox + col * (g * 2 + gap);
        final y = oy + row * (g * 2 + gap);
        final path = Path()
          ..moveTo(x + cut, y)
          ..lineTo(x + g * 2, y)
          ..lineTo(x + g * 2, y + g * 2)
          ..lineTo(x, y + g * 2)
          ..lineTo(x, y + cut)
          ..close();
        canvas.drawPath(path, p);
      }
    }
  }

  @override
  bool shouldRepaint(_ProjectsPainter old) => old.color != color;
}

// ── PaintsIcon (Tamiya jar) ───────────────────────────────────────────────────

class PaintsIcon extends StatelessWidget {
  final Color color;
  final double size;
  const PaintsIcon({super.key, required this.color, this.size = 24});

  @override
  Widget build(BuildContext context) => CustomPaint(
        size: Size(size, size),
        painter: _PaintsPainter(color),
      );
}

class _PaintsPainter extends CustomPainter {
  final Color color;
  _PaintsPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final sw = size.width;
    final sh = size.height;
    final cx = sw / 2;
    final cy = sh / 2;

    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = sw * 0.055
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final fill = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // Palette outline — kidney shape via two overlapping arcs
    // Outer arc: large ellipse-ish curve
    final path = Path();
    // Draw a palette shape: roughly oval with an indentation on the right side
    final r = sw * 0.42;
    final ox = cx - sw * 0.04;
    final oy = cy + sh * 0.02;

    path.addOval(Rect.fromCenter(
      center: Offset(ox, oy),
      width: sw * 0.84,
      height: sh * 0.78,
    ));

    // Thumb hole — punch out a small circle top-right
    final holeX = ox + sw * 0.18;
    final holeY = oy - sh * 0.18;
    final holePath = Path()
      ..addOval(Rect.fromCenter(
        center: Offset(holeX, holeY),
        width: sw * 0.22,
        height: sh * 0.22,
      ));

    final palettePath = Path.combine(PathOperation.difference, path, holePath);
    canvas.drawPath(palettePath, stroke);

    // Color dots on the palette surface
    final dots = [
      Offset(ox - sw * 0.22, oy - sh * 0.12),
      Offset(ox - sw * 0.10, oy - sh * 0.25),
      Offset(ox + sw * 0.06, oy - sh * 0.26),
      Offset(ox + sw * 0.20, oy - sh * 0.08),
      Offset(ox - sw * 0.24, oy + sh * 0.10),
    ];
    for (final dot in dots) {
      canvas.drawCircle(dot, sw * 0.055, fill);
    }
  }

  @override
  bool shouldRepaint(_PaintsPainter old) => old.color != color;
}

// ── RecipesIcon (flask) ───────────────────────────────────────────────────────

class RecipesIcon extends StatelessWidget {
  final Color color;
  final double size;
  const RecipesIcon({super.key, required this.color, this.size = 24});

  @override
  Widget build(BuildContext context) => CustomPaint(
        size: Size(size, size),
        painter: _RecipesPainter(color),
      );
}

class _RecipesPainter extends CustomPainter {
  final Color color;
  _RecipesPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final sw = size.width;
    final sh = size.height;
    final cx = sw / 2;

    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = sw * 0.055
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final fp = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // Flask neck top bar
    canvas.drawLine(Offset(cx - sw * 0.12, sh * 0.14),
        Offset(cx + sw * 0.12, sh * 0.14), p);

    // Neck sides
    canvas.drawLine(
        Offset(cx - sw * 0.06, sh * 0.14), Offset(cx - sw * 0.06, sh * 0.38), p);
    canvas.drawLine(
        Offset(cx + sw * 0.06, sh * 0.14), Offset(cx + sw * 0.06, sh * 0.38), p);

    // Body sides flaring out
    canvas.drawLine(Offset(cx - sw * 0.06, sh * 0.38),
        Offset(cx - sw * 0.28, sh * 0.84), p);
    canvas.drawLine(Offset(cx + sw * 0.06, sh * 0.38),
        Offset(cx + sw * 0.28, sh * 0.84), p);

    // Bottom
    canvas.drawLine(Offset(cx - sw * 0.28, sh * 0.84),
        Offset(cx + sw * 0.28, sh * 0.84), p);

    // Bubble inside flask
    canvas.drawCircle(Offset(cx + sw * 0.07, sh * 0.70), sw * 0.06, fp);
  }

  @override
  bool shouldRepaint(_RecipesPainter old) => old.color != color;
}

// ── SettingsIcon (angular gear 60°) ──────────────────────────────────────────

class SettingsIcon extends StatelessWidget {
  final Color color;
  final double size;
  const SettingsIcon({super.key, required this.color, this.size = 24});

  @override
  Widget build(BuildContext context) => CustomPaint(
        size: Size(size, size),
        painter: _SettingsPainter(color),
      );
}

class _SettingsPainter extends CustomPainter {
  final Color color;
  _SettingsPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final sw = size.width;
    final sh = size.height;
    final cx = sw / 2;
    final cy = sh / 2;

    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = sw * 0.055
      ..strokeCap = StrokeCap.butt
      ..strokeJoin = StrokeJoin.miter;

    final fp = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // Inner circle
    canvas.drawCircle(Offset(cx, cy), sw * 0.19, p);

    // 6 angular teeth at 60° intervals
    const teeth = 6;
    final outerR = sw * 0.40;
    final innerR = sw * 0.28;
    const hw = 0.18; // half-width of tooth in radians

    final path = Path();
    for (var i = 0; i < teeth; i++) {
      final base = (i / teeth) * math.pi * 2 - math.pi / 2;
      final aIn0 = base - hw * 1.4;
      final aOut0 = base - hw;
      final aOut1 = base + hw;
      final aIn3 = base + hw * 1.4;

      if (i == 0) {
        path.moveTo(
            cx + innerR * math.cos(aIn0), cy + innerR * math.sin(aIn0));
      } else {
        path.lineTo(
            cx + innerR * math.cos(aIn0), cy + innerR * math.sin(aIn0));
      }
      path.lineTo(cx + outerR * math.cos(aOut0), cy + outerR * math.sin(aOut0));
      path.lineTo(cx + outerR * math.cos(aOut1), cy + outerR * math.sin(aOut1));
      path.lineTo(cx + innerR * math.cos(aIn3), cy + innerR * math.sin(aIn3));

      final nextBase = ((i + 1) / teeth) * math.pi * 2 - math.pi / 2;
      final nextIn0 = nextBase - hw * 1.4;
      path.arcTo(
        Rect.fromCircle(center: Offset(cx, cy), radius: innerR),
        aIn3,
        nextIn0 - aIn3,
        false,
      );
    }
    path.close();
    canvas.drawPath(path, p);
  }

  @override
  bool shouldRepaint(_SettingsPainter old) => old.color != color;
}
