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
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: scheme.primary.withOpacity(0.4)),
            const SizedBox(height: 16),
            Text(
              title,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: scheme.onBackground,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Schermata in sviluppo',
              style: TextStyle(
                fontSize: 14,
                color: scheme.onBackground.withOpacity(0.4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
