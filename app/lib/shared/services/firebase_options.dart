// CONFIGURAZIONE FIREBASE — DA COMPLETARE
//
// Passi per generare questo file:
// 1. Vai su https://console.firebase.google.com
// 2. Crea un nuovo progetto (es. "patina-app")
// 3. Aggiungi un'app Android:
//    - Package name: com.patina.app  (verifica in android/app/build.gradle → applicationId)
//    - Scarica google-services.json → copialo in app/android/app/google-services.json
// 4. Installa FlutterFire CLI:
//    dart pub global activate flutterfire_cli
// 5. Dalla cartella /app esegui:
//    flutterfire configure --project=<nome-progetto-firebase>
//    → genera automaticamente questo file con i valori corretti
//
// NON committare google-services.json se contiene dati sensibili (aggiungerlo a .gitignore).

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        throw UnsupportedError('Piattaforma non configurata per Firebase.');
    }
  }

  // ⚠️  Sostituire con i valori reali generati da `flutterfire configure`
  static const FirebaseOptions android = FirebaseOptions(
    apiKey:            'DA_CONFIGURARE',
    appId:             'DA_CONFIGURARE',
    messagingSenderId: 'DA_CONFIGURARE',
    projectId:         'DA_CONFIGURARE',
    storageBucket:     'DA_CONFIGURARE',
  );
}
