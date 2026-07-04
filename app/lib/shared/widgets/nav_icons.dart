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

    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = sw * 0.055
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final fp = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final bw = sw * 0.58;
    final bh = sh * 0.46;
    final bx = cx - bw / 2;
    final by = cy - bh * 0.30;
    final bot = by + bh;
    final br = bw * 0.12;

    // Body
    final bodyPath = Path()
      ..moveTo(bx + br, by)
      ..lineTo(bx + bw - br, by)
      ..arcToPoint(Offset(bx + bw, by + br),
          radius: Radius.circular(br), clockwise: true)
      ..lineTo(bx + bw, bot - br)
      ..arcToPoint(Offset(bx + bw - br, bot),
          radius: Radius.circular(br), clockwise: true)
      ..lineTo(bx + br, bot)
      ..arcToPoint(Offset(bx, bot - br),
          radius: Radius.circular(br), clockwise: true)
      ..lineTo(bx, by + br)
      ..arcToPoint(Offset(bx + br, by),
          radius: Radius.circular(br), clockwise: true)
      ..close();
    canvas.drawPath(bodyPath, p);

    // Lid (slightly wider)
    final lidH = bh * 0.22;
    final lidW = bw + sw * 0.06;
    final lx = cx - lidW / 2;
    final lidTop = by - lidH;
    final lidR = lidH * 0.35;

    final lidPath = Path()
      ..moveTo(lx + lidR, lidTop)
      ..lineTo(lx + lidW - lidR, lidTop)
      ..arcToPoint(Offset(lx + lidW, lidTop + lidR),
          radius: Radius.circular(lidR), clockwise: true)
      ..lineTo(lx + lidW, by)
      ..lineTo(lx, by)
      ..lineTo(lx, lidTop + lidR)
      ..arcToPoint(Offset(lx + lidR, lidTop),
          radius: Radius.circular(lidR), clockwise: true)
      ..close();
    canvas.drawPath(lidPath, p);

    // Knurl lines on lid
    final kY1 = lidTop + lidH * 0.2;
    final kY2 = lidTop + lidH * 0.8;
    for (var i = -1; i <= 1; i++) {
      canvas.drawLine(
        Offset(cx + i * lidW * 0.22, kY1),
        Offset(cx + i * lidW * 0.22, kY2),
        p,
      );
    }

    // Label rect
    final lbW = bw * 0.70;
    final lbH = bh * 0.38;
    final lbX = cx - lbW / 2;
    final lbY = by + bh * 0.28;
    canvas.drawRect(Rect.fromLTWH(lbX, lbY, lbW, lbH), p);

    // Lines inside label
    final lm = lbW * 0.15;
    canvas.drawLine(
        Offset(lbX + lm, lbY + lbH * 0.35),
        Offset(lbX + lbW - lm, lbY + lbH * 0.35),
        p);
    canvas.drawLine(
        Offset(lbX + lm, lbY + lbH * 0.65),
        Offset(lbX + lbW - lm * 1.5, lbY + lbH * 0.65),
        p);
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
