import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

// ── Costanti prodotti RevenueCat ──────────────────────────────────────────────
//
// Creare su app.revenuecat.com:
//   Entitlement: "pro"
//   Products collegati:
//     - patina_standard_monthly  (1,99 €/mese)
//     - patina_standard_yearly   (12,99 €/anno)
//     - patina_pro_monthly       (3,99 €/mese)
//     - patina_pro_yearly        (24,99 €/anno)
//
// ⚠️  Sostituire con la API key reale (app.revenuecat.com → App settings → API keys → Public)
const _kRevenueCatApiKey = 'DA_CONFIGURARE';
const _kEntitlementPro = 'pro';

final revenueCatServiceProvider =
    Provider<RevenueCatService>((ref) => RevenueCatService());

class RevenueCatService {
  // Chiamare in main() dopo Firebase.initializeApp()
  static Future<void> init({String? userId}) async {
    await Purchases.setLogLevel(LogLevel.debug);
    final config = PurchasesConfiguration(_kRevenueCatApiKey);
    await Purchases.configure(config);
    if (userId != null) {
      await Purchases.logIn(userId);
    }
  }

  // Collega RevenueCat all'utente Firebase dopo il login
  Future<void> identifyUser(String firebaseUid) async {
    await Purchases.logIn(firebaseUid);
  }

  // Scollega al logout
  Future<void> logOut() async {
    await Purchases.logOut();
  }

  // Verifica se l'utente ha l'entitlement Pro attivo
  Future<bool> isProActive() async {
    try {
      final info = await Purchases.getCustomerInfo();
      return info.entitlements.active.containsKey(_kEntitlementPro);
    } catch (_) {
      return false;
    }
  }

  // Restituisce le offerte configurate su RevenueCat
  Future<Offerings?> getOfferings() async {
    try {
      return await Purchases.getOfferings();
    } catch (_) {
      return null;
    }
  }

  // Acquista un package
  Future<CustomerInfo?> purchase(Package package) async {
    try {
      return await Purchases.purchasePackage(package);
    } on PurchasesErrorCode catch (e) {
      if (e == PurchasesErrorCode.purchaseCancelledError) return null;
      rethrow;
    }
  }

  // Ripristina acquisti precedenti
  Future<CustomerInfo> restorePurchases() => Purchases.restorePurchases();
}
