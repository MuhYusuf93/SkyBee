package com.example.kasir_app

import android.content.pm.ApplicationInfo
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/** Included only in the explicitly requested standalone debug demo package. */
class SkybeeDemoActivity : MainActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "kasir_app/skybee_demo")
            .setMethodCallHandler { call, result ->
                if (call.method == "identity") {
                    result.success(mapOf("package" to packageName,
                        "debuggable" to (applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE != 0)))
                } else result.notImplemented()
            }
    }
}
