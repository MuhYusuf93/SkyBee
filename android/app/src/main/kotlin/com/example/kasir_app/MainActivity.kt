package com.example.kasir_app

import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMethodCodec

/** Same stored PBKDF2 verifier as Dart, computed off the Android UI thread.
 * Mbed TLS performs the complete KDF in one native call, avoiding hundreds of
 * thousands of high-level HMAC calls on ARM32. No credentials are logged.
 */
open class MainActivity : FlutterFragmentActivity() {
    companion object {
        private val nativeAvailable: Boolean by lazy {
            try {
                System.loadLibrary("kasir_pin_kdf")
                true
            } catch (_: UnsatisfiedLinkError) {
                false // Dart retains the identical algorithm/round count.
            }
        }
    }

    // Android's default native-method keep rule preserves this JNI name.
    private external fun nativeDerive(password: ByteArray, salt: ByteArray, rounds: Int): ByteArray?

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger
        val queue = messenger.makeBackgroundTaskQueue()
        MethodChannel(messenger, "kasir_app/pin_kdf", StandardMethodCodec.INSTANCE, queue)
            .setMethodCallHandler { call, result ->
                if (call.method == "backendInfo") {
                    result.success(mapOf("backend" to "Mbed TLS 3.6.7 PBKDF2-HMAC-SHA256",
                        "available" to nativeAvailable, "mainThread" to
                            (android.os.Looper.myLooper() == android.os.Looper.getMainLooper())))
                    return@setMethodCallHandler
                }
                if (call.method != "derivePbkdf2Sha256") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                // Dart supplies its exact UTF8 bytes, avoiding differences in
                // Java/Dart malformed-surrogate encoding. Never log the bytes.
                val password = call.argument<ByteArray>("password")
                val salt = call.argument<ByteArray>("salt")
                // Valid rounds/bits fit the codec's Int32 range. Reject Double
                // or oversized Long rather than silently truncating parameters.
                val rounds = call.argument<Any>("iterations") as? Int
                val bits = call.argument<Any>("bits") as? Int
                if (password == null || salt == null || salt.size < 16 ||
                    rounds == null || rounds !in 600000..2000000 || bits != 256) {
                    password?.fill(0)
                    result.error("KDF_PARAMETERS", null, null)
                    return@setMethodCallHandler
                }
                try {
                    if (!nativeAvailable) {
                        result.error("KDF_UNAVAILABLE", null, null)
                    } else {
                        val key = nativeDerive(password, salt, rounds)
                        if (key == null || key.size != 32) {
                            result.error("KDF_FAILED", null, null)
                        } else {
                            result.success(key)
                        }
                    }
                } catch (_: UnsatisfiedLinkError) {
                    result.error("KDF_UNAVAILABLE", null, null)
                } finally {
                    password.fill(0)
                }
            }
    }
}
