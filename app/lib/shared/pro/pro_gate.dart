import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kDevProKey = 'dev_pro_override';

// Provider reale dello stato Pro.
// In Fase 3 (milestone 3.1) sostituire con il provider Google Play Billing / Apple IAP.
// Fino ad allora: false di default, sovrascrivibile tramite toggle sviluppatore
// nelle Impostazioni (visibile solo in debug build).
final proStatusProvider =
    StateNotifierProvider<ProStatusNotifier, bool>((_) => ProStatusNotifier());

class ProStatusNotifier extends StateNotifier<bool> {
  ProStatusNotifier() : super(false) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool(_kDevProKey) ?? false;
  }

  Future<void> setDevOverride(bool value) async {
    state = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kDevProKey, value);
  }
}

abstract final class ProGate {
  /// Restituisce true se l'utente ha un abbonamento Pro attivo.
  static bool isProUser(WidgetRef ref) => ref.read(proStatusProvider);

  /// Restituisce true se l'utente ha un abbonamento Pro attivo (watch).
  static bool watchProUser(WidgetRef ref) => ref.watch(proStatusProvider);
}
