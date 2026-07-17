package com.patina.app

import androidx.core.splashscreen.SplashScreen.Companion.installSplashScreen
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        // Installa il native splash prima di Flutter — necessario su API 31+
        installSplashScreen()
        super.onCreate(savedInstanceState)
    }
}
