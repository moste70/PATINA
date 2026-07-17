import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// Placeholder paywall — da sostituire con UI definitiva in Fase 3 (milestone 3.1)
// quando Google Play Billing / Apple IAP saranno integrati.
//
// Uso:
//   if (!ProGate.isProUser(ref)) {
//     PaywallSheet.show(context, feature: 'Scansione AI');
//     return;
//   }
class PaywallSheet extends StatelessWidget {
  final String feature;
  const PaywallSheet._({required this.feature});

  static Future<void> show(BuildContext context, {required String feature}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => PaywallSheet._(feature: feature),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: scheme.outline,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Icon(Icons.workspace_premium_outlined,
                size: 48, color: scheme.primary),
            const SizedBox(height: 16),
            Text(
              'Funzionalità Pro',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: scheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '"$feature" è disponibile con PATINA Pro.',
              style: tt.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Sblocca tutte le funzionalità AI con un abbonamento mensile o annuale.',
              style: tt.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            // TODO(fase3-3.1): collegare a Google Play Billing / Apple IAP
            FilledButton(
              onPressed: () => Navigator.pop(context),
              style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
              ),
              child: const Text('Disponibile prossimamente'),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Non ora'),
            ),
          ],
        ),
      ),
    );
  }
}
