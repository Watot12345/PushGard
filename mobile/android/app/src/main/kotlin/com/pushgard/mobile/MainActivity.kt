package com.pushgard.mobile

import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        try {
            flutterEngine.plugins.add(NativeCameraPosePlugin())
        } catch (t: Throwable) {
            Log.e("PushGard", "Failed to register NativeCameraPosePlugin", t)
        }
    }
}
