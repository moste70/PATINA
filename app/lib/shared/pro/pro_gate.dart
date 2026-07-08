import 'package:flutter_riverpod/flutter_riverpod.dart';

// Stub: restituisce sempre false finché Google Play Billing / Apple IAP
// non vengono integrati in Fase 3 (milestone 3.1).
// Sostituire con il provider reale che legge lo stato dell'abbonamento.
final proStatusProvider = Provider<bool>((_) => false);

abstract final class ProGate {
  /// Restituisce true se l'utente ha un abbonamento Pro attivo.
  static bool isProUser(WidgetRef ref) => ref.read(proStatusProvider);

  /// Restituisce true se l'utente ha un abbonamento Pro attivo (watch).
  static bool watchProUser(WidgetRef ref) => ref.watch(proStatusProvider);
}
