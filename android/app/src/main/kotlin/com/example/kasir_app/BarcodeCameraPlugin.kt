package com.example.kasir_app

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.hardware.Camera
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.view.View
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import com.google.zxing.BarcodeFormat
import com.google.zxing.DecodeHintType
import com.google.zxing.BinaryBitmap
import com.google.zxing.MultiFormatReader
import com.google.zxing.MultiFormatWriter
import com.google.zxing.RGBLuminanceSource
import com.google.zxing.ResultPoint
import com.google.zxing.common.HybridBinarizer
import com.journeyapps.barcodescanner.BarcodeCallback
import com.journeyapps.barcodescanner.BarcodeResult
import com.journeyapps.barcodescanner.BarcodeView
import com.journeyapps.barcodescanner.CameraPreview
import com.journeyapps.barcodescanner.DefaultDecoderFactory
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

/** One foreground camera owner, no images/files/network. Lifecycle pause never
 * automatically resumes decoding: the Dart scope must explicitly re-authorize.
 * The bundled decoder is pure Java; it introduces no camera-native ABI dependency.
 */
@Suppress("DEPRECATION")
internal class BarcodeCameraPlugin(private val activity: FlutterFragmentActivity, engine: FlutterEngine) {
    companion object {
        const val PERMISSION_REQUEST = 37214
        val formats = listOf(BarcodeFormat.EAN_13, BarcodeFormat.EAN_8, BarcodeFormat.UPC_A,
            BarcodeFormat.UPC_E, BarcodeFormat.CODE_128, BarcodeFormat.CODE_39,
            BarcodeFormat.ITF, BarcodeFormat.QR_CODE)
        // UPC-A and zero-prefixed EAN-13 share bars. Preserve the 13-digit
        // result; Dart offers an explicit 12-digit alternative instead of
        // silently dropping a leading zero during lookup.
        val decoderFormats = formats.filter { it != BarcodeFormat.UPC_A }
    }
    private val messenger = engine.dartExecutor.binaryMessenger
    private val channel = MethodChannel(messenger, "kasir_app/barcode_camera")
    private val views = mutableMapOf<Int, CameraView>()
    private var active: CameraView? = null
    private var pendingPermission: MethodChannel.Result? = null
    private val permissionTimeout = Handler(Looper.getMainLooper())
    private var permissionInFlight = false
    private var disposed = false

    private fun permitted() = ContextCompat.checkSelfPermission(activity, Manifest.permission.CAMERA) == PackageManager.PERMISSION_GRANTED
    private fun cameras(): Int = try { Camera.getNumberOfCameras().coerceIn(0, 16) } catch (_: Exception) { 0 }
    private fun probe(): Map<String, Any> {
        val count = cameras()
        return mapOf("available" to (count > 0), "cameras" to count,
            "permission" to permitted(), "sdk" to Build.VERSION.SDK_INT, "offline" to true,
            "decoder" to "ZXing Android Embedded 4.3.0 / core 3.4.1")
    }

    init {
        engine.platformViewsController.registry.registerViewFactory("kasir_app/barcode_camera",
            object : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
                override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
                    return CameraView(context, viewId).also { views[viewId] = it }
                }
            })
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "probe" -> result.success(probe())
                "permission" -> {
                    if (disposed) result.error("CLOSED", null, null)
                    else if (cameras() == 0 || permitted()) result.success(probe())
                    else if (permissionInFlight) result.error("BUSY", null, null)
                    else {
                        pendingPermission = result
                        permissionInFlight = true
                        ActivityCompat.requestPermissions(activity, arrayOf(Manifest.permission.CAMERA), PERMISSION_REQUEST)
                        permissionTimeout.postDelayed({
                            if (pendingPermission === result) {
                                pendingPermission = null
                                result.error("PERMISSION_TIMEOUT", null, null)
                            }
                        }, 60000)
                    }
                }
                "decodeQrRasterFixture" -> {
                    // Disposable integration package only. Decode actual Dart
                    // printer pixels with an independent Java decoder;
                    // this is never a production camera-frame injection path.
                    if (activity.packageName != "com.example.kasir_app.integration") result.notImplemented()
                    else try {
                        val width = call.argument<Int>("width") ?: 0
                        val height = call.argument<Int>("height") ?: 0
                        val packed = call.argument<ByteArray>("pixels")
                        require(width in 192..640 && height in 192..960)
                        val stride = (width + 7) / 8
                        require(packed != null && packed.size == stride * height)
                        val pixels = IntArray(width * height) { i ->
                            val x = i % width
                            val y = i / width
                            val dark = (packed[y * stride + x / 8].toInt() and (128 shr (x % 8))) != 0
                            if (dark) 0xff000000.toInt() else 0xffffffff.toInt()
                        }
                        val decoded = MultiFormatReader().decode(
                            BinaryBitmap(HybridBinarizer(RGBLuminanceSource(width, height, pixels))),
                            mapOf(DecodeHintType.POSSIBLE_FORMATS to listOf(BarcodeFormat.QR_CODE)))
                        result.success(mapOf("text" to decoded.text,
                            "format" to decoded.barcodeFormat.name, "physicalCamera" to false))
                    } catch (_: Exception) { result.error("DECODE_FAILED", null, null) }
                }
                "decodeFixture" -> {
                    // No production injection of camera frames or fake scans.
                    if (activity.packageName != "com.example.kasir_app.integration") result.notImplemented()
                    else try {
                        val text = "0000123456789"
                        val matrix = MultiFormatWriter().encode(text, BarcodeFormat.CODE_128, 640, 160)
                        val pixels = IntArray(matrix.width * matrix.height) { i ->
                            if (matrix.get(i % matrix.width, i / matrix.width)) 0xff000000.toInt() else 0xffffffff.toInt()
                        }
                        val bitmap = BinaryBitmap(HybridBinarizer(RGBLuminanceSource(matrix.width, matrix.height, pixels)))
                        val decoded = MultiFormatReader().decode(bitmap)
                        val ean = MultiFormatWriter().encode("0123456789012", BarcodeFormat.EAN_13, 640, 160)
                        val eanPixels = IntArray(ean.width * ean.height) { i ->
                            if (ean.get(i % ean.width, i / ean.width)) 0xff000000.toInt() else 0xffffffff.toInt()
                        }
                        val eanDecoded = MultiFormatReader().decode(BinaryBitmap(HybridBinarizer(
                            RGBLuminanceSource(ean.width, ean.height, eanPixels))),
                            mapOf(DecodeHintType.POSSIBLE_FORMATS to decoderFormats))
                        result.success(mapOf("text" to decoded.text, "format" to decoded.barcodeFormat.name,
                            "eanText" to eanDecoded.text, "eanFormat" to eanDecoded.barcodeFormat.name, "physicalCamera" to false))
                    } catch (_: Exception) { result.error("DECODE_FAILED", null, null) }
                }
                else -> result.notImplemented()
            }
        }
    }

    fun permissionResult(requestCode: Int) {
        if (requestCode != PERMISSION_REQUEST) return
        val pending = pendingPermission
        pendingPermission = null
        permissionInFlight = false
        pending?.success(probe())
    }

    fun pauseAll() { views.values.toList().forEach { it.pause() }; active = null }
    fun dispose() {
        if (disposed) return
        disposed = true
        views.values.toList().forEach { it.dispose() }
        views.clear()
        pendingPermission?.error("CLOSED", null, null)
        pendingPermission = null
        permissionTimeout.removeCallbacksAndMessages(null)
        channel.setMethodCallHandler(null)
    }

    private inner class CameraView(context: Context, private val id: Int) : PlatformView {
        private val barcode = BarcodeView(context)
        private val calls = MethodChannel(messenger, "kasir_app/barcode_camera/$id")
        private var closed = false
        private var armed = false
        private var generation = 0

        init {
            barcode.setUseTextureView(true)
            barcode.decoderFactory = DefaultDecoderFactory(decoderFormats)
            barcode.addStateListener(object : CameraPreview.StateListener {
                override fun previewSized() {}
                override fun previewStarted() { if (!closed && armed) calls.invokeMethod("started", null) }
                override fun previewStopped() {}
                override fun cameraClosed() {}
                override fun cameraError(error: Exception) { pause(); if (!closed) calls.invokeMethod("error", "CAMERA_ERROR") }
            })
            calls.setMethodCallHandler { call, result ->
                when (call.method) {
                    "arm" -> {
                        val token = call.argument<Int>("token")
                        if (closed || disposed) result.error("CLOSED", null, null)
                        else if (token == null || token <= 0) result.error("INVALID_ARM", null, null)
                        else if (!permitted()) result.error("PERMISSION", null, null)
                        else if (cameras() == 0) result.error("NO_CAMERA", null, null)
                        else try {
                            if (active !== this) active?.pause()
                            active = this
                            val epoch = ++generation
                            armed = true
                            barcode.resume()
                            barcode.decodeSingle(object : BarcodeCallback {
                                override fun barcodeResult(value: BarcodeResult) {
                                    if (closed || !armed || epoch != generation) return
                                    armed = false
                                    val text = value.text
                                    if (text.length !in 1..256 || value.barcodeFormat !in formats) {
                                        calls.invokeMethod("error", "INVALID_CODE")
                                    } else {
                                        calls.invokeMethod("decoded", mapOf("text" to text, "format" to value.barcodeFormat.name, "token" to token))
                                    }
                                    // decodeSingle stops its decoder after this callback. Pause
                                    // asynchronously to avoid restarting inside that callback.
                                    barcode.post { if (!armed && !closed && epoch == generation) barcode.pause() }
                                }
                                override fun possibleResultPoints(points: List<ResultPoint>) {}
                            })
                            result.success(null)
                        } catch (_: Exception) { pause(); result.error("CAMERA_ERROR", null, null) }
                    }
                    "pause" -> { pause(); result.success(null) }
                    else -> result.notImplemented()
                }
            }
        }
        fun pause() {
            armed = false
            generation++
            barcode.pause()
            if (active === this) active = null
        }
        override fun getView(): View = barcode
        override fun dispose() {
            if (closed) return
            pause()
            closed = true
            calls.setMethodCallHandler(null)
            views.remove(id)
        }
    }
}
