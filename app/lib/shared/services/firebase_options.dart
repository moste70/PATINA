// Generato manualmente dai valori di google-services.json (patina-app-173cc).
// Per rigenerare: dart pub global activate flutterfire_cli && flutterfire configure

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions non è configurato per questa piattaforma.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey:            'AIzaSyBi9wq8jooa9FB8UIw3Ta39bVJ5Y1tUNBg',
    appId:             '1:434846246006:android:91218fa3d016f324712b57',
    messagingSenderId: '434846246006',
    projectId:         'patina-app-173cc',
    storageBucket:     'patina-app-173cc.firebasestorage.app',
  );
}
