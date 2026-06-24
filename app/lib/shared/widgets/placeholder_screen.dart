import 'dart:math' as math;
import 'package:flutter/material.dart';

class PlaceholderScreen extends StatelessWidget {
  final String title;
  final IconData icon;

  const PlaceholderScreen({
    super.key,
    required this.title,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.background,
      appBar: AppBar(
        backgroundColor: scheme.background,
        leading: Padding(
          padding: const EdgeInsets.all(10),
          child: _PatinaIcon(color: scheme.primary),
        ),
        title: const Text('PATINA', style: TextStyle(letterSpacing: 2.5, fontSize: 16)),
        actions: [
          IconButton(
            icon: const Icon(Icons.search_outlined),
            onPressed: () {},
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: scheme.surfaceVariant,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: scheme.outline, width: 1),
              ),
              child: Icon(icon, size: 36, color: scheme.primary.withOpacity(0.6)),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: scheme.onBackground,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'In sviluppo',
              style: TextStyle(
                fontSize: 13,
                color: scheme.onSurface.withOpacity(0.4),
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PatinaIcon extends StatelessWidget {
  final Color color;
  const _PatinaIcon({required this.color});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _HexPainter(color: color));
  }
}

class _HexPainter extends CustomPainter {
  final Color color;
  _HexPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;

    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width * 0.46;

    final path = Path();
    for (int i = 0; i < 6; i++) {
      final angle = (i * 60 - 30) * math.pi / 180;
      final ax = cx + r * math.cos(angle);
      final ay = cy + r * math.sin(angle);
      if (i == 0) {
        path.moveTo(ax, ay);
      } else {
        path.lineTo(ax, ay);
      }
    }
    path.close();
    canvas.drawPath(path, paint);

    canvas.drawCircle(
      Offset(cx, cy),
      size.width * 0.1,
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(_HexPainter old) => old.color != color;
}
