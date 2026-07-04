import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

// ─── Timing constants (ms) ────────────────────────────────────────────────────
const _kTotalMs       = 3400;
const _kStep          = 320;   // gap tra esagoni dell'anello
const _kHexDur        = 360;   // durata animazione ingresso singolo hex
const _kCentralDelay  = _kStep * 6 + 200; // 2120ms — centrale per ultimo
const _kTextStart     = _kCentralDelay + 480; // 2600ms
const _kTextDur       = 500;
const _kNavigateDelay = _kTotalMs + 600;

// ─── Geometry (spazio 120×120, flat-top, R=20) ────────────────────────────────
// Ordine anello: top(0) → top-right(1) → bot-right(2) → bottom(3) → bot-left(4) → top-left(5)
// Ordine vertici per hex: left, top-left, top-right, right, bot-right, bot-left
const _kPolys = <List<Offset>>[
  [Offset(40,25.36),Offset(50,8.04),  Offset(70,8.04),  Offset(80,25.36),Offset(70,42.68), Offset(50,42.68)],  // 0 top
  [Offset(70,42.68),Offset(80,25.36), Offset(100,25.36),Offset(110,42.68),Offset(100,60),  Offset(80,60)],     // 1 top-right
  [Offset(70,77.32),Offset(80,60),    Offset(100,60),   Offset(110,77.32),Offset(100,94.64),Offset(80,94.64)], // 2 bot-right
  [Offset(40,94.64),Offset(50,77.32), Offset(70,77.32), Offset(80,94.64),Offset(70,111.96),Offset(50,111.96)],// 3 bottom
  [Offset(10,77.32),Offset(20,60),    Offset(40,60),    Offset(50,77.32),Offset(40,94.64), Offset(20,94.64)],  // 4 bot-left
  [Offset(10,42.68),Offset(20,25.36), Offset(40,25.36), Offset(50,42.68),Offset(40,60),    Offset(20,60)],     // 5 top-left
  [Offset(40,60),   Offset(50,42.68), Offset(70,42.68), Offset(80,60),   Offset(70,77.32), Offset(50,77.32)],  // 6 centrale
];

// Palette: gradiente orario da pallido (top) a saturo (bottom) e ritorno
const _kColors = <Color>[
  Color(0xFFD8CFBE), // top        — ottone pallido, luce diretta
  Color(0xFFDEC295), // top-right  — chiaro
  Color(0xFFEC9C26), // bot-right  — oro caldo
  Color(0xFFEF8E08), // bottom     — più saturo
  Color(0xFFE7A848), // bot-left   — oro medio
  Color(0xFFE4B56E), // top-left   — caldo chiaro (ritorno)
  Color(0xFFD99B3E), // centrale   — accent Ottone
];

// ─── EaseOutBack curve ────────────────────────────────────────────────────────
class _EaseOutBack extends Curve {
  const _EaseOutBack();

  @override
  double transformInternal(double t) {
    const c1 = 1.70158;
    const c3 = c1 + 1;
    return 1 + c3 * math.pow(t - 1, 3) + c1 * math.pow(t - 1, 2);
  }
}

// ─── SplashScreen widget ──────────────────────────────────────────────────────
class SplashScreen extends StatefulWidget {
  /// Se true, dopo l'animazione naviga a /projects; altrimenti a /onboarding.
  final bool onboardingCompleted;

  const SplashScreen({super.key, required this.onboardingCompleted});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final AnimationController _breatheCtrl;

  // Per-hex alpha (0→1, easeOut)
  late final List<Animation<double>> _hexAlpha;
  // Per-hex scale (easeOutBack: leggero rimbalzo all'ingresso)
  late final List<Animation<double>> _hexScaleRaw;

  late final Animation<double> _glowAlpha;
  late final Animation<double> _textAlpha;
  late final Animation<double> _textSlide; // 1.0=giù, 0.0=in posto

  @override
  void initState() {
    super.initState();

    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: _kTotalMs),
    );

    _breatheCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4000),
    )..repeat();

    // Costruisce le animation per ogni hex con il delay corretto
    _hexAlpha = List.generate(7, (i) {
      final delayMs = i < 6 ? i * _kStep : _kCentralDelay;
      final start = delayMs / _kTotalMs;
      final end   = (delayMs + _kHexDur) / _kTotalMs;
      return CurvedAnimation(
        parent: _ctrl,
        curve: Interval(start.clamp(0, 1), end.clamp(0, 1),
            curve: Curves.easeOut),
      );
    });

    _hexScaleRaw = List.generate(7, (i) {
      final delayMs = i < 6 ? i * _kStep : _kCentralDelay;
      final start = delayMs / _kTotalMs;
      // easeOutBack richiede un po' di tempo extra oltre l'alpha
      final end   = (delayMs + _kHexDur * 1.15) / _kTotalMs;
      return CurvedAnimation(
        parent: _ctrl,
        curve: Interval(start.clamp(0, 1), end.clamp(0, 1),
            curve: const _EaseOutBack()),
      );
    });

    const glowEnd = (_kStep * 6 + 200) / _kTotalMs;
    _glowAlpha = CurvedAnimation(
      parent: _ctrl,
      curve: Interval(0, glowEnd.clamp(0, 1), curve: Curves.easeOut),
    );

    final textStart = _kTextStart / _kTotalMs;
    final textEnd   = (_kTextStart + _kTextDur) / _kTotalMs;
    _textAlpha = CurvedAnimation(
      parent: _ctrl,
      curve: Interval(textStart, textEnd.clamp(0, 1), curve: Curves.easeOut),
    );
    _textSlide = CurvedAnimation(
      parent: _ctrl,
      curve: Interval(textStart, textEnd.clamp(0, 1), curve: Curves.easeOut),
    );

    _ctrl.forward();

    Future.delayed(const Duration(milliseconds: _kNavigateDelay), () {
      if (mounted) {
        context.go(widget.onboardingCompleted ? '/projects' : '/onboarding');
      }
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _breatheCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final markPx = math.min(size.width, size.height) * 0.38;
    final fontSize = markPx * 0.195;

    // Posizione mark: centrata orizzontale, leggermente sopra il centro
    final markTop = (size.height - markPx) / 2 - markPx * 0.08;

    return Scaffold(
      backgroundColor: const Color(0xFF1C1A16),
      body: AnimatedBuilder(
        animation: Listenable.merge([_ctrl, _breatheCtrl]),
        builder: (context, _) {
          final hexAlphaValues = _hexAlpha.map((a) => a.value).toList();
          final hexScaleValues = _hexScaleRaw
              .map((a) => (0.45 + 0.55 * a.value).clamp(0.0, 1.15))
              .toList();

          // Breathing: seno su glow e radius
          final breatheT = _breatheCtrl.value;
          final breathePulse = 0.055 * math.sin(breatheT * 2 * math.pi);

          // Glow alpha: animazione principale + breathing idle
          final glowBase = _glowAlpha.value * 0.20;
          final glowFinal = _ctrl.isCompleted
              ? (0.20 + breathePulse * 0.7).clamp(0.05, 0.40)
              : glowBase;

          return Stack(
            children: [
              // ── Marchio animato ──────────────────────────────────────────
              Positioned.fill(
                child: CustomPaint(
                  painter: _SplashMarkPainter(
                    hexAlpha:   hexAlphaValues,
                    hexScale:   hexScaleValues,
                    glowAlpha:  glowFinal,
                    glowRadius: 0.8 + (_ctrl.isCompleted ? breathePulse * 0.5 : 0),
                    markPx:     markPx,
                    markTop:    markTop,
                  ),
                ),
              ),

              // ── Wordmark ─────────────────────────────────────────────────
              Positioned(
                left: 0, right: 0,
                top: markTop + markPx + fontSize * 0.6,
                child: Opacity(
                  opacity: _textAlpha.value,
                  child: Transform.translate(
                    offset: Offset(0, (1 - _textSlide.value) * 20),
                    child: Column(
                      children: [
                        Text(
                          'PATINA',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.jetBrainsMono(
                            color: const Color(0xFFECEDE4),
                            fontWeight: FontWeight.w800,
                            fontSize: fontSize,
                            letterSpacing: fontSize * 0.14,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'SCALE MODELING COMPANION',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.jetBrainsMono(
                            color: const Color(0xFFD99B3E),
                            fontWeight: FontWeight.w400,
                            fontSize: fontSize * 0.30,
                            letterSpacing: fontSize * 0.10,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ─── CustomPainter: marchio + glow ───────────────────────────────────────────
class _SplashMarkPainter extends CustomPainter {
  final List<double> hexAlpha;
  final List<double> hexScale;
  final double glowAlpha;
  final double glowRadius; // moltiplicatore di markPx
  final double markPx;
  final double markTop;

  const _SplashMarkPainter({
    required this.hexAlpha,
    required this.hexScale,
    required this.glowAlpha,
    required this.glowRadius,
    required this.markPx,
    required this.markTop,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final s  = markPx / 120.0;
    final ox = (size.width - 120 * s) / 2;
    final oy = markTop;

    canvas.save();
    canvas.translate(ox, oy);

    // — Glow radiale Ottone —
    if (glowAlpha > 0) {
      final center = Offset(60 * s, 60 * s);
      final r = markPx * glowRadius;
      final paint = Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFD99B3E).withOpacity(glowAlpha),
            const Color(0xFFD99B3E).withOpacity(glowAlpha * 0.3),
            const Color(0xFFD99B3E).withOpacity(0),
          ],
          stops: const [0.0, 0.6, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: r));
      canvas.drawRect(
        Rect.fromLTWH(-r, -r, 120 * s + r * 2, 120 * s + r * 2),
        paint,
      );
    }

    // — Passaggio 1: tutti i fill —
    for (var i = 0; i < 7; i++) {
      _drawFill(canvas, _kPolys[i], _kColors[i], hexAlpha[i], hexScale[i], s);
    }
    // — Passaggio 2: tutti gli stroke (giunture uniformi) —
    for (var i = 0; i < 7; i++) {
      _drawStroke(canvas, _kPolys[i], hexAlpha[i], hexScale[i], s);
    }

    canvas.restore();
  }

  void _drawFill(
    Canvas canvas, List<Offset> poly, Color color,
    double alpha, double scale, double s,
  ) {
    if (alpha <= 0) return;
    final center = _polyCenter(poly, s);

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.scale(scale, scale);
    canvas.translate(-center.dx, -center.dy);

    final path = _polyPath(poly, s);
    canvas.save();
    canvas.clipPath(path);

    // Base fill
    canvas.drawPath(path, Paint()
      ..color = color.withOpacity(alpha)
      ..style = PaintingStyle.fill);

    // Gradiente direzionale: top-left chiaro → bottom-right scuro
    final bounds = path.getBounds();
    canvas.drawRect(
      bounds,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withOpacity(0.20 * alpha),
            Colors.white.withOpacity(0.04 * alpha),
            Colors.black.withOpacity(0.28 * alpha),
          ],
          stops: const [0.0, 0.4, 1.0],
        ).createShader(bounds),
    );

    canvas.restore(); // clip
    canvas.restore(); // transform
  }

  void _drawStroke(
    Canvas canvas, List<Offset> poly,
    double alpha, double scale, double s,
  ) {
    if (alpha <= 0) return;
    final center = _polyCenter(poly, s);

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.scale(scale, scale);
    canvas.translate(-center.dx, -center.dy);

    canvas.drawPath(
      _polyPath(poly, s),
      Paint()
        ..color = Colors.black.withOpacity(0.50 * alpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..strokeJoin = StrokeJoin.round,
    );

    canvas.restore();
  }

  Offset _polyCenter(List<Offset> poly, double s) => Offset(
    poly.map((p) => p.dx).reduce((a, b) => a + b) / poly.length * s,
    poly.map((p) => p.dy).reduce((a, b) => a + b) / poly.length * s,
  );

  Path _polyPath(List<Offset> poly, double s) {
    final path = Path()..moveTo(poly[0].dx * s, poly[0].dy * s);
    for (var j = 1; j < poly.length; j++) {
      path.lineTo(poly[j].dx * s, poly[j].dy * s);
    }
    return path..close();
  }

  @override
  bool shouldRepaint(_SplashMarkPainter old) =>
      hexAlpha != old.hexAlpha ||
      hexScale != old.hexScale ||
      glowAlpha != old.glowAlpha ||
      glowRadius != old.glowRadius;
}
