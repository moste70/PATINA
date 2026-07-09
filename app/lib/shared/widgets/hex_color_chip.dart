import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Chip colore esagonale flat-top (lato orizzontale in cima).
/// Usare in liste, palette kit, risultati OCR, shopping list.
class HexColorChip extends StatelessWidget {
  final Color color;
  final double size;
  final Color? borderColor;
  final Widget? child;

  const HexColorChip({
    super.key,
    required this.color,
    this.size = 32,
    this.borderColor,
    this.child,
  });

  /// Relative luminance (WCAG formula) — determines if a contrast border is needed.
  static double _luminance(Color c) {
    double lin(int v) {
      final s = v / 255.0;
      return s <= 0.04045 ? s / 12.92 : ((s + 0.055) / 1.055) * ((s + 0.055) / 1.055);
    }
    return 0.2126 * lin(c.red) + 0.7152 * lin(c.green) + 0.0722 * lin(c.blue);
  }

  @override
  Widget build(BuildContext context) {
    // Auto-contrast border: light chip → dark outline, dark chip → light outline.
    final lum = _luminance(color);
    final autoBorder = lum > 0.18
        ? Colors.black.withOpacity(0.25)
        : Colors.white.withOpacity(0.35);
    final border = borderColor ?? autoBorder;
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _HexBorderPainter(borderColor: border),
        child: ClipPath(
          clipper: _FlatTopHexClipper(),
          child: Container(
            width: size,
            height: size,
            color: color,
            child: child,
          ),
        ),
      ),
    );
  }
}

class _FlatTopHexClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final w = size.width;
    final h = size.height;
    return Path()
      ..moveTo(w * 0.25, 0)
      ..lineTo(w * 0.75, 0)
      ..lineTo(w, h * 0.5)
      ..lineTo(w * 0.75, h)
      ..lineTo(w * 0.25, h)
      ..lineTo(0, h * 0.5)
      ..close();
  }

  @override
  bool shouldReclip(_FlatTopHexClipper old) => false;
}

class _HexBorderPainter extends CustomPainter {
  final Color borderColor;
  _HexBorderPainter({required this.borderColor});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final path = Path()
      ..moveTo(w * 0.25, 0)
      ..lineTo(w * 0.75, 0)
      ..lineTo(w, h * 0.5)
      ..lineTo(w * 0.75, h)
      ..lineTo(w * 0.25, h)
      ..lineTo(0, h * 0.5)
      ..close();
    canvas.drawPath(
      path,
      Paint()
        ..color = borderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );
  }

  @override
  bool shouldRepaint(_HexBorderPainter old) => old.borderColor != borderColor;
}
