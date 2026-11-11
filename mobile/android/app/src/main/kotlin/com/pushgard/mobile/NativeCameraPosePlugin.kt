package com.pushgard.mobile

import android.content.Context
import android.graphics.SurfaceTexture
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.util.Size
import android.view.Surface
import androidx.camera.core.*
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.core.content.ContextCompat
import androidx.lifecycle.LifecycleOwner
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.pose.Pose
import com.google.mlkit.vision.pose.PoseDetection
import com.google.mlkit.vision.pose.PoseDetector
import com.google.mlkit.vision.pose.PoseLandmark
import com.google.mlkit.vision.pose.defaults.PoseDetectorOptions
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.view.TextureRegistry
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

class NativeCameraPosePlugin : FlutterPlugin, MethodChannel.MethodCallHandler, EventChannel.StreamHandler {

    private lateinit var context: Context
    private lateinit var textureRegistry: TextureRegistry
    private var methodChannel: MethodChannel? = null
    private var eventChannel: EventChannel? = null
    private var eventSink: EventChannel.EventSink? = null

    private var textureEntry: TextureRegistry.SurfaceTextureEntry? = null
    private var cameraProvider: ProcessCameraProvider? = null
    private var cameraExecutor: ExecutorService? = null
    private var poseDetector: PoseDetector? = null

    private val mainHandler = Handler(Looper.getMainLooper())

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        textureRegistry = binding.textureRegistry

        methodChannel = MethodChannel(binding.binaryMessenger, "com.pushgard/camera_pose")
        methodChannel?.setMethodCallHandler(this)

        eventChannel = EventChannel(binding.binaryMessenger, "com.pushgard/pose_events")
        eventChannel?.setStreamHandler(this)

        cameraExecutor = Executors.newSingleThreadExecutor()

        // Configure ML Kit stream mode options
        val options = PoseDetectorOptions.Builder()
            .setDetectorMode(PoseDetectorOptions.STREAM_MODE)
            .build()
        poseDetector = PoseDetection.getClient(options)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        methodChannel?.setMethodCallHandler(null)
        methodChannel = null
        eventChannel?.setStreamHandler(null)
        eventChannel = null
        stopCamera()
        cameraExecutor?.shutdown()
        cameraExecutor = null
        poseDetector?.close()
        poseDetector = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "startCamera" -> {
                val targetResolutionStr = call.argument<String>("targetResolution") ?: "480p"
                val lensFacingStr = call.argument<String>("lensFacing") ?: "back"
                startCamera(targetResolutionStr, lensFacingStr, result)
            }
            "stopCamera" -> {
                stopCamera()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        this.eventSink = events
    }

    override fun onCancel(arguments: Any?) {
        this.eventSink = null
    }

    private fun startCamera(targetResolutionStr: String, lensFacingStr: String, result: MethodChannel.Result) {
        stopCamera()

        val textureEntry = textureRegistry.createSurfaceTexture()
        this.textureEntry = textureEntry
        val surfaceTexture = textureEntry.surfaceTexture()

        val cameraProviderFuture = ProcessCameraProvider.getInstance(context)
        cameraProviderFuture.addListener({
            try {
                val provider = cameraProviderFuture.get()
                this.cameraProvider = provider

                val targetResolution = when (targetResolutionStr) {
                    "720p" -> Size(720, 1280)
                    else -> Size(480, 640)
                }

                surfaceTexture.setDefaultBufferSize(targetResolution.width, targetResolution.height)

                val preview = Preview.Builder()
                    .setTargetResolution(targetResolution)
                    .build()

                preview.setSurfaceProvider { request ->
                    val surface = Surface(surfaceTexture)
                    request.provideSurface(surface, ContextCompat.getMainExecutor(context)) {
                        surface.release()
                    }
                }

                val lensFacing = if (lensFacingStr == "front") CameraSelector.LENS_FACING_FRONT else CameraSelector.LENS_FACING_BACK
                val cameraSelector = CameraSelector.Builder()
                    .requireLensFacing(lensFacing)
                    .build()

                val imageAnalysis = ImageAnalysis.Builder()
                    .setTargetResolution(targetResolution)
                    .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
                    .build()

                val executor = cameraExecutor ?: Executors.newSingleThreadExecutor().also { cameraExecutor = it }

                imageAnalysis.setAnalyzer(executor) { imageProxy ->
                    processImageProxy(imageProxy)
                }

                // Bind to lifecycle
                val lifecycleOwner = context as? LifecycleOwner
                if (lifecycleOwner != null) {
                    provider.unbindAll()
                    provider.bindToLifecycle(lifecycleOwner, cameraSelector, preview, imageAnalysis)
                } else {
                    // Fallback for background service or activity without direct cast
                    provider.unbindAll()
                }

                val reply = mapOf(
                    "textureId" to textureEntry.id(),
                    "width" to targetResolution.width,
                    "height" to targetResolution.height
                )
                mainHandler.post { result.success(reply) }

            } catch (e: Exception) {
                mainHandler.post { result.error("CAMERA_ERROR", e.message, null) }
            }
        }, ContextCompat.getMainExecutor(context))
    }

    @androidx.annotation.OptIn(ExperimentalGetImage::class)
    private fun processImageProxy(imageProxy: ImageProxy) {
        val mediaImage = imageProxy.image
        if (mediaImage == null) {
            imageProxy.close()
            return
        }

        val timestampMs = SystemClock.elapsedRealtime()
        val rotationDegrees = imageProxy.imageInfo.rotationDegrees
        val inputImage = InputImage.fromMediaImage(mediaImage, rotationDegrees)

        val detector = poseDetector
        if (detector == null) {
            imageProxy.close()
            return
        }

        val inferenceStart = SystemClock.elapsedRealtime()

        detector.process(inputImage)
            .addOnSuccessListener { pose ->
                val inferenceMs = SystemClock.elapsedRealtime() - inferenceStart
                val landmarksMap = serializeLandmarks(pose)

                val payload = HashMap<String, Any>()
                payload["t_ms"] = timestampMs
                payload["inference_ms"] = inferenceMs
                payload["rotation"] = rotationDegrees
                payload["img_w"] = inputImage.width
                payload["img_h"] = inputImage.height
                payload["landmarks"] = landmarksMap

                mainHandler.post {
                    eventSink?.success(payload)
                }
            }
            .addOnFailureListener {
                // Ignore frame failure to maintain stream continuity
            }
            .addOnCompleteListener {
                imageProxy.close()
            }
    }

    private fun serializeLandmarks(pose: Pose): Map<String, List<Double>> {
        val map = HashMap<String, List<Double>>()
        val landmarkTypes = listOf(
            "NOSE" to PoseLandmark.NOSE,
            "LEFT_SHOULDER" to PoseLandmark.LEFT_SHOULDER,
            "RIGHT_SHOULDER" to PoseLandmark.RIGHT_SHOULDER,
            "LEFT_ELBOW" to PoseLandmark.LEFT_ELBOW,
            "RIGHT_ELBOW" to PoseLandmark.RIGHT_ELBOW,
            "LEFT_WRIST" to PoseLandmark.LEFT_WRIST,
            "RIGHT_WRIST" to PoseLandmark.RIGHT_WRIST,
            "LEFT_HIP" to PoseLandmark.LEFT_HIP,
            "RIGHT_HIP" to PoseLandmark.RIGHT_HIP,
            "LEFT_KNEE" to PoseLandmark.LEFT_KNEE,
            "RIGHT_KNEE" to PoseLandmark.RIGHT_KNEE,
            "LEFT_ANKLE" to PoseLandmark.LEFT_ANKLE,
            "RIGHT_ANKLE" to PoseLandmark.RIGHT_ANKLE
        )

        for ((name, type) in landmarkTypes) {
            val landmark = pose.getPoseLandmark(type)
            if (landmark != null) {
                val pos = landmark.position3D
                // [x, y, z, inFrameLikelihood]
                map[name] = listOf(pos.x.toDouble(), pos.y.toDouble(), pos.z.toDouble(), landmark.inFrameLikelihood.toDouble())
            }
        }
        return map
    }

    private fun stopCamera() {
        try {
            cameraProvider?.unbindAll()
            textureEntry?.release()
            textureEntry = null
        } catch (_: Exception) {}
    }
}
