package com.example.kasir_app

import android.os.Bundle
import android.content.ClipboardManager
import android.app.NotificationManager
import android.app.Notification
import android.view.WindowManager
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/** Keeps only the isolated test window awake; no system setting or wake lock.
 * This source directory is excluded from ordinary APKs by the isolation flag.
 */
class IntegrationActivity : MainActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Read-only fixture boundary: no screenshot, display configuration or
        // data access. Confirms production protectedScreen applies its OS flag.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger,
            "kasir_app/window_probe").setMethodCallHandler { call, result ->
            if (packageName != "com.example.kasir_app.integration") {
                result.error("probe_unavailable", "Isolated fixture required.", null)
            } else when (call.method) {
                "secureFlag" -> result.success(window.attributes.flags and
                    WindowManager.LayoutParams.FLAG_SECURE != 0)
                "hasFocus" -> result.success(hasWindowFocus())
                else -> result.notImplemented()
            }
        }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger,
            "kasir_app/notification_probe").setMethodCallHandler { call, result ->
            val id = call.argument<Int>("id")
            if (call.method != "metadata") result.notImplemented()
            else if (packageName != "com.example.kasir_app.integration" || id == null ||
                id !in 1777000000..1777999999) {
                result.error("probe_unavailable", "Public fixture notification required.", null)
            } else {
                val manager = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
                val note = manager.activeNotifications.firstOrNull { it.id == id &&
                    it.packageName == packageName }?.notification
                result.success(mapOf("exists" to (note != null),
                    "privateVisibility" to (note?.visibility == Notification.VISIBILITY_PRIVATE)))
            }
        }
        // Fixture-only diagnostic: never read an Item, text, URI, or secret.
        // The probe calls this only after explicitly copying its PUBLIC value
        // through the production plugin. Ordinary builds exclude this class.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger,
            "kasir_app/clipboard_probe").setMethodCallHandler { call, result ->
            if (call.method != "describePublicClip") {
                result.notImplemented()
            } else if (packageName != "com.example.kasir_app.integration" || !hasWindowFocus()) {
                result.error("probe_inactive", "Foreground fixture required.", null)
            } else {
                val clipboard = getSystemService(CLIPBOARD_SERVICE) as ClipboardManager
                val description = clipboard.primaryClipDescription
                val owned = description?.label?.toString() == "Backup recovery code"
                result.success(mapOf(
                    "ownLabel" to owned,
                    "sensitive" to (owned && description?.extras?.getBoolean(
                        "android.content.extra.IS_SENSITIVE", false) == true),
                    "plainTextMime" to (owned && description?.hasMimeType("text/plain") == true)))
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        check(packageName == "com.example.kasir_app.integration")
        super.onCreate(savedInstanceState)
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
    }
}
