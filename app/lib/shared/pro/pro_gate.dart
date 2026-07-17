import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kDevProKey = 'dev_pro_override';

// ── Provider stato Pro ────────────────────────────────────────────────────────
//
// Un solo provider per entrambe le modalità:
//
//   DEBUG:    legge dev_pro_override da SharedPreferences
//             → toggle visibile in Impostazioni › Developer
//
//   RELEASE:  legge users/{uid}/isPro da Firestore in realtime
//             → aggiornato automaticamente da webhook RevenueCat → Firebase Function
//             → quando l'abbonamento cambia stato l'app si aggiorna senza riavvio

final proStatusProvider =
    StateNotifierProvider<ProStatusNotifier, bool>(
      (_) => ProStatusNotifier(),
    );

class ProStatusNotifier extends StateNotifier<bool> {
  StreamSubscription<DocumentSnapshot>? _firestoreSub;

  ProStatusNotifier() : super(false) {
    if (kDebugMode) {
      _loadDevOverride();
    } else {
      _subscribeFirestore();
    }
  }

  // ── Debug — SharedPreferences ─────────────────────────────────────────────

  Future<void> _loadDevOverride() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) state = prefs.getBool(_kDevProKey) ?? false;
  }

  Future<void> setDevOverride(bool value) async {
    assert(kDebugMode, 'setDevOverride è disponibile solo in debug build');
    state = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kDevProKey, value);
  }

  // ── Release — Firestore realtime ──────────────────────────────────────────

  void _subscribeFirestore() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    _firestoreSub = FirebaseFirestore.instance
        .doc('users/$uid')
        .snapshots()
        .listen((snap) {
      if (mounted) state = snap.data()?['isPro'] == true;
    });
  }

  // Chiamare dopo login/logout per aggiornare la subscription
  void onAuthChanged(String? uid) {
    if (kDebugMode) return;
    _firestoreSub?.cancel();
    _firestoreSub = null;
    if (uid != null) _subscribeFirestore();
    if (mounted) state = false;
  }

  @override
  void dispose() {
    _firestoreSub?.cancel();
    super.dispose();
  }
}

// ── Helper ────────────────────────────────────────────────────────────────────

abstract final class ProGate {
  /// true se l'utente ha un abbonamento Pro attivo.
  static bool isProUser(WidgetRef ref) => ref.read(proStatusProvider);

  /// true se l'utente ha un abbonamento Pro attivo (watch — ricostruisce il widget).
  static bool watchProUser(WidgetRef ref) => ref.watch(proStatusProvider);
}
