package com.example.kasir_app

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.graphics.Color
import android.graphics.Bitmap
import android.graphics.Rect
import android.graphics.drawable.GradientDrawable
import android.hardware.Camera
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.view.MotionEvent
import android.view.View
import android.view.ViewConfiguration
import android.widget.FrameLayout
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
import com.journeyapps.barcodescanner.SourceData
import com.journeyapps.barcodescanner.camera.FitCenterStrategy
import com.journeyapps.barcodescanner.camera.PreviewCallback
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory
import java.io.ByteArrayOutputStream
import java.util.concurrent.Executors
import kotlin.math.roundToInt

/** One foreground camera owner. Receipt photos are encoded in memory. Lifecycle pause never
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
        private val focusModes = setOf(Camera.Parameters.FOCUS_MODE_AUTO,
            Camera.Parameters.FOCUS_MODE_MACRO, Camera.Parameters.FOCUS_MODE_CONTINUOUS_PICTURE,
            Camera.Parameters.FOCUS_MODE_CONTINUOUS_VIDEO)

        /** Preview pixels already include the decoder's scale and crop. Undo
         * the display rotation before using Camera1 sensor coordinates. */
        private fun focusArea(x: Float, y: Float, frame: Rect, crop: Rect,
                              width: Int, height: Int, rotation: Int): Rect? {
            if (frame.isEmpty || crop.isEmpty || width <= 0 || height <= 0) return null
            val u = (crop.left + (x - frame.left) * crop.width() / frame.width()) / width
            val v = (crop.top + (y - frame.top) * crop.height() / frame.height()) / height
            if (u !in 0f..1f || v !in 0f..1f) return null
            val (sensorX, sensorY) = when (rotation) {
                0 -> u to v
                90 -> v to (1 - u)
                180 -> (1 - u) to (1 - v)
                270 -> (1 - v) to u
                else -> return null
            }
            val cx = (sensorX * 2000 - 1000).roundToInt()
            val cy = (sensorY * 2000 - 1000).roundToInt()
            return Rect((cx - 150).coerceAtLeast(-1000), (cy - 150).coerceAtLeast(-1000),
                (cx + 150).coerceAtMost(1000), (cy + 150).coerceAtMost(1000))
        }
    }
    private val messenger = engine.dartExecutor.binaryMessenger
    private val channel = MethodChannel(messenger, "kasir_app/barcode_camera")
    private val views = mutableMapOf<Int, CameraView>()
    private val photoWorker = Executors.newSingleThreadExecutor()
    private var active: CameraView? = null
    private var pendingPermission: MethodChannel.Result? = null
    private val permissionTimeout = Handler(Looper.getMainLooper())
    private var permissionInFlight = false
    private var disposed = false

    private fun permitted() = ContextCompat.checkSelfPermission(activity, Manifest.permission.CAMERA) == PackageManager.PERMISSION_GRANTED
    private fun cameras(): Int = try { Camera.getNumberOfCameras().coerceIn(0, 16) } catch (_: Exception) { 0 }
    private fun hasRearCamera(): Boolean = try {
        val info = Camera.CameraInfo()
        (0 until cameras()).any {
            Camera.getCameraInfo(it, info)
            info.facing == Camera.CameraInfo.CAMERA_FACING_BACK
        }
    } catch (_: Exception) { false }
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
                    val receiptPhoto = (args as? Map<*, *>)?.get("receiptPhoto") == true
                    return CameraView(context, viewId, receiptPhoto).also { views[viewId] = it }
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
        photoWorker.shutdownNow()
        pendingPermission?.error("CLOSED", null, null)
        pendingPermission = null
        permissionTimeout.removeCallbacksAndMessages(null)
        channel.setMethodCallHandler(null)
    }

    private inner class CameraView(context: Context, private val id: Int, private val receiptPhoto: Boolean) : PlatformView {
        private val barcode = BarcodeView(context)
        private val preview = FrameLayout(context)
        private val ring = View(context)
        private val ringSize = (40 * context.resources.displayMetrics.density).roundToInt()
        private val hideRing = Runnable { ring.visibility = View.INVISIBLE }
        private val calls = MethodChannel(messenger, "kasir_app/barcode_camera/$id")
        private var closed = false
        private var armed = false
        private var photoResult: MethodChannel.Result? = null
        private val photoTimeout = Runnable { finishPhoto(null) }
        @Volatile
        private var generation = 0

        init {
            barcode.setUseTextureView(true)
            if (receiptPhoto) barcode.previewScalingStrategy = FitCenterStrategy()
            preview.addView(barcode, FrameLayout.LayoutParams(-1, -1))
            ring.importantForAccessibility = View.IMPORTANT_FOR_ACCESSIBILITY_NO
            ring.background = GradientDrawable().apply {
                shape = GradientDrawable.OVAL
                setStroke((ringSize / 20).coerceAtLeast(1), Color.WHITE)
            }
            ring.visibility = View.INVISIBLE
            preview.addView(ring, FrameLayout.LayoutParams(ringSize, ringSize))
            listenForFocus(context)
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
                        else if (receiptPhoto) result.error("INVALID_ARM", null, null)
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
                    "armPhoto" -> {
                        if (!receiptPhoto || closed || disposed || !permitted() || cameras() == 0) {
                            result.error("PHOTO_UNAVAILABLE", null, null)
                        } else try {
                            if (active !== this) active?.pause()
                            active = this
                            generation++
                            armed = true
                            barcode.resume()
                            result.success(null)
                        } catch (_: Exception) {
                            pause()
                            result.error("PHOTO_UNAVAILABLE", null, null)
                        }
                    }
                    "capturePhoto" -> capturePhoto(result)
                    "pause" -> { pause(); result.success(null) }
                    else -> result.notImplemented()
                }
            }
        }

        /** Capture the uncropped, oriented preview frame through the current
         * owner. JPEG encoding cannot block the camera or platform thread. */
        private fun capturePhoto(result: MethodChannel.Result) {
            val camera = barcode.cameraInstance
            if (!receiptPhoto || closed || !armed || active !== this ||
                !barcode.isPreviewActive || camera == null || photoResult != null) {
                result.error("PHOTO_UNAVAILABLE", null, null)
                return
            }
            photoResult = result
            val epoch = generation
            preview.postDelayed(photoTimeout, 7000)
            try {
                camera.requestPreview(object : PreviewCallback {
                    override fun onPreview(frame: SourceData) {
                        try {
                            photoWorker.execute {
                                val bytes = try { encodeReceiptPhoto(frame) } catch (_: Exception) { null }
                                preview.post {
                                    if (photoResult === result && generation == epoch) finishPhoto(bytes)
                                }
                            }
                        } catch (_: Exception) {
                            onPreviewError(IllegalStateException())
                        }
                    }

                    override fun onPreviewError(error: Exception) {
                        preview.post {
                            if (photoResult === result && generation == epoch) finishPhoto(null)
                        }
                    }
                })
            } catch (_: Exception) {
                finishPhoto(null)
            }
        }

        private fun finishPhoto(bytes: ByteArray?) {
            preview.removeCallbacks(photoTimeout)
            val result = photoResult ?: return
            photoResult = null
            if (bytes == null) result.error("PHOTO_UNAVAILABLE", null, null) else result.success(bytes)
        }

        private fun listenForFocus(context: Context) {
            val slop = ViewConfiguration.get(context).scaledTouchSlop
            var downX = 0f
            var downY = 0f
            var tap = false
            barcode.setOnTouchListener { _, event ->
                when (event.actionMasked) {
                    MotionEvent.ACTION_DOWN -> {
                        downX = event.x
                        downY = event.y
                        tap = armed
                    }
                    MotionEvent.ACTION_MOVE -> {
                        if (kotlin.math.abs(event.x - downX) > slop ||
                            kotlin.math.abs(event.y - downY) > slop) tap = false
                    }
                    MotionEvent.ACTION_UP -> {
                        if (tap) focusAt(event.x, event.y)
                        tap = false
                    }
                    MotionEvent.ACTION_POINTER_DOWN, MotionEvent.ACTION_CANCEL -> tap = false
                }
                true
            }
        }

        private fun focusAt(x: Float, y: Float) {
            if (closed || !armed || !barcode.isPreviewActive) return
            val camera = barcode.cameraInstance ?: return
            val frame = barcode.framingRect ?: return
            val crop = barcode.previewFramingRect ?: return
            val size = barcode.previewSize ?: return
            // ZXing chooses the first rear camera. Keep its normal autofocus on
            // front-only devices, where the preview may also be mirrored.
            if (!hasRearCamera()) return
            val area = focusArea(x, y, frame, crop, size.width, size.height, camera.cameraRotation) ?: return
            val epoch = generation
            // This public ZXing callback runs on the existing camera thread.
            // The normal autofocus cycle uses the requested area. The ring
            // acknowledges the request, since the driver reports no lock here.
            barcode.changeCameraParameters { parameters ->
                if (generation == epoch && parameters.maxNumFocusAreas > 0 &&
                    parameters.focusMode in focusModes) {
                    parameters.focusAreas = listOf(Camera.Area(area, 1000))
                    preview.post {
                        if (!closed && armed && generation == epoch) {
                            ring.translationX = x - ringSize / 2f
                            ring.translationY = y - ringSize / 2f
                            ring.visibility = View.VISIBLE
                            ring.removeCallbacks(hideRing)
                            ring.postDelayed(hideRing, 700)
                        }
                    }
                }
                parameters
            }
        }

        fun pause() {
            armed = false
            generation++
            finishPhoto(null)
            ring.removeCallbacks(hideRing)
            hideRing.run()
            barcode.pause()
            if (active === this) active = null
        }
        override fun getView(): View = preview
        override fun dispose() {
            if (closed) return
            pause()
            closed = true
            calls.setMethodCallHandler(null)
            views.remove(id)
        }
    }

    private fun encodeReceiptPhoto(frame: SourceData): ByteArray {
        val pixels = frame.dataWidth.toLong() * frame.dataHeight
        require(pixels in 4096L..8_300_000L)
        val original = frame.getBitmap(null, if (pixels > 6_000_000) 2 else 1)
        try {
            val scale = minOf(1.0, 1280.0 / original.width, 2560.0 / original.height)
            val width = (original.width * scale).roundToInt()
            val height = (original.height * scale).roundToInt()
            require(width >= 64 && height >= 64)
            val sized = if (scale < 1.0) Bitmap.createScaledBitmap(original, width, height, true) else original
            try {
                for (quality in listOf(74, 68)) {
                    val out = ByteArrayOutputStream()
                    require(sized.compress(Bitmap.CompressFormat.JPEG, quality, out))
                    val bytes = stripReceiptPhotoMetadata(out.toByteArray())
                    if (bytes.size <= 768 * 1024) return bytes
                }
                throw IllegalArgumentException()
            } finally {
                if (sized !== original) sized.recycle()
            }
        } finally {
            original.recycle()
        }
    }

    /** Preserve image coding segments and skip optional application metadata
     * from the encoder. Camera sensor data is never written to a temporary file. */
    private fun stripReceiptPhotoMetadata(bytes: ByteArray): ByteArray {
        val output = ByteArrayOutputStream(bytes.size)
        output.write(bytes, 0, 2)
        var start = 2
        while (start + 4 < bytes.size) {
            require((bytes[start].toInt() and 255) == 255)
            var index = start + 1
            while (index < bytes.size && (bytes[index].toInt() and 255) == 255) index++
            require(index + 2 < bytes.size)
            val marker = bytes[index++].toInt() and 255
            val length = ((bytes[index].toInt() and 255) shl 8) or (bytes[index + 1].toInt() and 255)
            require(length >= 2 && index + length < bytes.size)
            if (marker == 0xda) {
                output.write(bytes, start, bytes.size - start)
                return output.toByteArray()
            }
            if (marker != 0xfe && (marker !in 0xe1..0xef || marker == 0xee)) {
                output.write(bytes, start, index + length - start)
            }
            start = index + length
        }
        throw IllegalArgumentException()
    }
}
