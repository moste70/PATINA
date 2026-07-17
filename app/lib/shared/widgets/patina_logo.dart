import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Marchio PATINA — anello esagonale (design system v1.0).
///
/// Vettoriale, disegnato con [CustomPainter]: nessuna dipendenza esterna
/// (niente flutter_svg), nitido a qualsiasi dimensione.
///
/// Esempi:
/// ```dart
/// const PatinaMark(size: 40)                    // a colori (6 toni ottone)
/// const PatinaMark(size: 24, monoColor: Color(0xFFD99B3E))  // tinta unita
/// const PatinaLockup(markSize: 32)              // mark + scritta "PATINA"
/// ```
class PatinaMark extends StatelessWidget {
  /// Lato del marchio in logical pixel. Il marchio è quadrato.
  final double size;

  /// Se valorizzato, il marchio è disegnato in tinta unita con questo colore
  /// (es. Ottone `#D99B3E`). Lascia `null` per la versione a colori.
  final Color? monoColor;

  const PatinaMark({super.key, this.size = 48, this.monoColor});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _PatinaMarkPainter(monoColor)),
    );
  }
}

/// Ottone — colore-firma PATINA.
const Color kPatinaOttone = Color(0xFFD99B3E);

class _PatinaMarkPainter extends CustomPainter {
  final Color? mono;
  _PatinaMarkPainter(this.mono);

  // 7 esagoni flat-top, spazio 120×120, R=20.
  // 6 esagoni esterni si toccano per un lato fra loro;
  // il 7° (centrale) condivide un lato con ognuno dei 6.
  // Centri esterni a distanza R√3 ≈ 34.64 dal centro (60,60).
  static const List<List<Offset>> _polys = [
    // Anello esterno — orario partendo dall'alto
    [Offset(40, 25.36), Offset(50,  8.04), Offset(70,  8.04), Offset(80, 25.36), Offset(70, 42.68), Offset(50, 42.68)], // alto
    [Offset(70, 42.68), Offset(80, 25.36), Offset(100, 25.36), Offset(110, 42.68), Offset(100, 60), Offset(80, 60)],    // alto-destra
    [Offset(70, 77.32), Offset(80, 60),    Offset(100, 60),    Offset(110, 77.32), Offset(100, 94.64), Offset(80, 94.64)], // basso-destra
    [Offset(40, 94.64), Offset(50, 77.32), Offset(70, 77.32),  Offset(80, 94.64), Offset(70, 111.96), Offset(50, 111.96)], // basso
    [Offset(10, 77.32), Offset(20, 60),    Offset(40, 60),     Offset(50, 77.32), Offset(40, 94.64),  Offset(20, 94.64)],  // basso-sinistra
    [Offset(10, 42.68), Offset(20, 25.36), Offset(40, 25.36),  Offset(50, 42.68), Offset(40, 60),     Offset(20, 60)],    // alto-sinistra
    // Centrale — condivide un lato con ognuno dei 6 esterni
    [Offset(40, 60),    Offset(50, 42.68), Offset(70, 42.68),  Offset(80, 60),    Offset(70, 77.32),  Offset(50, 77.32)],
  ];

  // Saturazione crescente sull'anello = "la patina"; centro = Ottone pieno.
  static const List<Color> _colors = [
    Color(0xFFEC9C26), Color(0xFFEF8E08), Color(0xFFE7A848),
    Color(0xFFDEC295), Color(0xFFD8CFBE), Color(0xFFE4B56E),
    Color(0xFFD99B3E), // centrale — accent Ottone
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final double s = size.width / 120.0;
    final paint = Paint()
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    for (var i = 0; i < _polys.length; i++) {
      paint.color = mono ?? _colors[i];
      final poly = _polys[i];
      final path = Path()..moveTo(poly[0].dx * s, poly[0].dy * s);
      for (var j = 1; j < poly.length; j++) {
        path.lineTo(poly[j].dx * s, poly[j].dy * s);
      }
      path.close();
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_PatinaMarkPainter old) => old.mono != mono;
}

/// Lockup orizzontale: marchio + wordmark "PATINA" in JetBrains Mono 800.
class PatinaLockup extends StatelessWidget {
  final double markSize;
  final Color textColor;

  const PatinaLockup({
    super.key,
    this.markSize = 36,
    this.textColor = const Color(0xFFECEAE4), // Calce
  });

  @override
  Widget build(BuildContext context) {
    final fontSize = markSize * 0.62;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        PatinaMark(size: markSize),
        SizedBox(width: markSize * 0.34),
        Text(
          'PATINA',
          style: GoogleFonts.jetBrainsMono(
            color: textColor,
            fontWeight: FontWeight.w800,
            fontSize: fontSize,
            letterSpacing: fontSize * 0.12,
          ),
        ),
      ],
    );
  }
}
