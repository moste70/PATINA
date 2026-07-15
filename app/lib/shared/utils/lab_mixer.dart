import 'dart:math' as math;
import 'package:flutter/material.dart';

Color hexToColor(String hex) {
  try {
    return Color(int.parse(hex.replaceFirst('#', '0xFF')));
  } catch (_) {
    return Colors.grey;
  }
}

/// Blends a list of (hex, weight) pairs in CIE L*a*b* space.
/// Weights are normalized internally so they don't need to sum to 100.
Color blendColorsInLab(List<({String hex, double weight})> paints) {
  if (paints.isEmpty) return Colors.grey.shade600;
  if (paints.length == 1) return hexToColor(paints.first.hex);
  final total = paints.fold(0.0, (s, p) => s + p.weight);
  if (total <= 0) return hexToColor(paints.first.hex);
  double L = 0, a = 0, b = 0;
  for (final p in paints) {
    final lab = _rgbToLab(hexToColor(p.hex));
    final w = p.weight / total;
    L += lab.$1 * w;
    a += lab.$2 * w;
    b += lab.$3 * w;
  }
  return _labToRgb(L, a, b);
}

/// CIE76 ΔE — perceptual color distance.
double deltaE(Color c1, Color c2) {
  final l1 = _rgbToLab(c1);
  final l2 = _rgbToLab(c2);
  return math.sqrt(
    math.pow(l1.$1 - l2.$1, 2) +
    math.pow(l1.$2 - l2.$2, 2) +
    math.pow(l1.$3 - l2.$3, 2),
  );
}

// ── Internal helpers ──────────────────────────────────────────────────────────

(double, double, double) _rgbToLab(Color c) {
  final r = _lin(c.red / 255.0);
  final g = _lin(c.green / 255.0);
  final bl = _lin(c.blue / 255.0);
  final X = r * 0.4124564 + g * 0.3575761 + bl * 0.1804375;
  final Y = r * 0.2126729 + g * 0.7151522 + bl * 0.0721750;
  final Z = r * 0.0193339 + g * 0.1191920 + bl * 0.9503041;
  final fx = _f(X / 0.95047);
  final fy = _f(Y);
  final fz = _f(Z / 1.08883);
  return (116.0 * fy - 16.0, 500.0 * (fx - fy), 200.0 * (fy - fz));
}

Color _labToRgb(double L, double a, double b) {
  final fy = (L + 16.0) / 116.0;
  final fx = a / 500.0 + fy;
  final fz = fy - b / 200.0;
  final X = _fInv(fx) * 0.95047;
  final Y = _fInv(fy);
  final Z = _fInv(fz) * 1.08883;
  final r = X * 3.2404542 + Y * -1.5371385 + Z * -0.4985314;
  final g = X * -0.9692660 + Y * 1.8760108 + Z * 0.0415560;
  final bl = X * 0.0556434 + Y * -0.2040259 + Z * 1.0572252;
  return Color.fromARGB(
    255,
    (_delin(r.clamp(0, 1)) * 255).round().clamp(0, 255),
    (_delin(g.clamp(0, 1)) * 255).round().clamp(0, 255),
    (_delin(bl.clamp(0, 1)) * 255).round().clamp(0, 255),
  );
}

double _lin(double c) =>
    c <= 0.04045 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();

double _delin(double c) =>
    c <= 0.0031308 ? c * 12.92 : 1.055 * math.pow(c, 1.0 / 2.4) - 0.055;

double _f(double t) =>
    t > 0.008856 ? math.pow(t, 1.0 / 3.0).toDouble() : 7.787 * t + 16.0 / 116.0;

double _fInv(double t) =>
    t > 0.206897 ? t * t * t : (t - 16.0 / 116.0) / 7.787;
