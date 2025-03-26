package com.example.screentranslator

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.hardware.display.DisplayManager
import android.hardware.display.VirtualDisplay
import android.media.ImageReader
import android.media.projection.MediaProjection
import android.media.projection.MediaProjectionManager
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.util.Log
import java.io.File
import java.io.FileOutputStream

class ScreenCaptureService : Service() {
    private val NOTIFICATION_ID = 1
    private val CHANNEL_ID = "screen_capture_channel"

    private var mediaProjection: MediaProjection? = null
    private var imageReader: ImageReader? = null
    private var virtualDisplay: VirtualDisplay? = null
    private var shouldUseAppProjection = false

    companion object {
        private const val TAG = "ScreenCaptureService"
        const val EXTRA_RESULT_CODE = "result_code"
        const val EXTRA_DATA = "data"
        const val EXTRA_PATH = "path"
        const val EXTRA_USE_APP_PROJECTION = "use_app_projection"
        const val ACTION_START = "start"
        const val ACTION_STOP = "stop"

        // For sending results back to MainActivity
        const val ACTION_SCREENSHOT_RESULT = "screenshot_result"
        const val EXTRA_SUCCESS = "success"
    }

    override fun onBind(intent: Intent?): IBinder? {
        return null
    }

    override fun onCreate() {
        super.onCreate()
        startForeground()
        Log.d(TAG, "Service created")
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.d(TAG, "Service started with intent: ${intent?.action}")

        if (intent == null) {
            stopSelf()
            return START_NOT_STICKY
        }

        when (intent.action) {
            ACTION_START -> {
                val resultCode = intent.getIntExtra(EXTRA_RESULT_CODE, 0) // Changed default from -1 to 0
                val data = intent.getParcelableExtra<Intent>(EXTRA_DATA)
                val path = intent.getStringExtra(EXTRA_PATH)
                shouldUseAppProjection = intent.getBooleanExtra(EXTRA_USE_APP_PROJECTION, false)

                Log.d(TAG, "Action START received: resultCode=$resultCode, data=$data, path=$path, useAppProjection=$shouldUseAppProjection")

                if (path != null) {
                    try {
                        // We no longer use the Application's stored MediaProjection
                        // Instead, we create a new one here in the service
                        if (shouldUseAppProjection && MyApplication.hasProjectionCredentials()) {
                            // Get the stored credentials and create a projection here
                            Log.d(TAG, "Using application's stored credentials")
                            val projManager = getSystemService(Context.MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
                            val storedCode = MyApplication.resultCode
                            val storedData = MyApplication.resultData

                            // FIXED: In Android, RESULT_OK is -1, so we need to check for -1 specifically
                            Log.d(TAG, "Stored credentials: code=$storedCode, data=${storedData != null}")
                            if (storedCode == -1 && storedData != null) { // RESULT_OK is -1
                                try {
                                    mediaProjection = projManager.getMediaProjection(storedCode, storedData)
                                    if (mediaProjection != null) {
                                        Log.d(TAG, "Successfully created MediaProjection in service")
                                        setupImageReaderAndVirtualDisplay(path)
                                    } else {
                                        Log.e(TAG, "Failed to create MediaProjection in service")
                                        sendFailureResult(path)
                                        stopSelf()
                                    }
                                } catch (e: Exception) {
                                    Log.e(TAG, "Error creating projection from credentials", e)
                                    sendFailureResult(path)
                                    stopSelf()
                                }
                            } else {
                                Log.e(TAG, "Invalid stored credentials: code=$storedCode, data=${storedData != null}")
                                sendFailureResult(path)
                                stopSelf()
                            }
                        } else if (resultCode == -1 && data != null) { // RESULT_OK is -1
                            // Use the projection from intent
                            Log.d(TAG, "Using projection from intent")
                            startCapture(resultCode, data, path)
                        } else {
                            Log.e(TAG, "No valid projection available: resultCode=$resultCode, data=${data != null}")
                            sendFailureResult(path)
                            stopSelf()
                        }
                    } catch (e: Exception) {
                        Log.e(TAG, "Error starting capture", e)
                        sendFailureResult(path)
                        stopSelf()
                    }
                } else {
                    Log.e(TAG, "Invalid path parameter")
                    sendFailureResult("unknown")
                    stopSelf()
                }
            }
            ACTION_STOP -> {
                Log.d(TAG, "Action STOP received")
                stopSelf()
            }
            else -> {
                Log.d(TAG, "Unknown action: ${intent.action}")
                stopSelf()
            }
        }

        return START_NOT_STICKY
    }

    private fun startForeground() {
        // Create Notification Channel (required for Android 8+)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Screen Capture",
                NotificationManager.IMPORTANCE_LOW
            )
            channel.description = "Used for capturing screen content"

            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.createNotificationChannel(channel)
            Log.d(TAG, "Notification channel created")
        }

        // Create Notification
        val notification = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }
            .setContentTitle("Screen Translator")
            .setContentText("Capturing screen...")
            .setSmallIcon(android.R.drawable.ic_menu_camera)
            .build()

        // Start Foreground Service
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(NOTIFICATION_ID, notification, android.content.pm.ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PROJECTION)
            Log.d(TAG, "Service started in foreground with MEDIA_PROJECTION type")
        } else {
            startForeground(NOTIFICATION_ID, notification)
            Log.d(TAG, "Service started in foreground")
        }
    }

    private fun sendSuccessResult(path: String) {
        try {
            val resultIntent = Intent(ACTION_SCREENSHOT_RESULT)
            resultIntent.putExtra(EXTRA_SUCCESS, true)
            resultIntent.putExtra(EXTRA_PATH, path)
            sendBroadcast(resultIntent)
            Log.d(TAG, "Sent success broadcast: path=$path")
        } catch (e: Exception) {
            Log.e(TAG, "Error sending success broadcast", e)
        }
    }

    private fun sendFailureResult(path: String) {
        try {
            val resultIntent = Intent(ACTION_SCREENSHOT_RESULT)
            resultIntent.putExtra(EXTRA_SUCCESS, false)
            resultIntent.putExtra(EXTRA_PATH, path)
            sendBroadcast(resultIntent)
            Log.d(TAG, "Sent failure broadcast: path=$path")
        } catch (e: Exception) {
            Log.e(TAG, "Error sending failure broadcast", e)
        }
    }

    private fun startCapture(resultCode: Int, data: Intent, path: String) {
        try {
            val mediaProjectionManager = getSystemService(Context.MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
            mediaProjection = mediaProjectionManager.getMediaProjection(resultCode, data)

            if (mediaProjection == null) {
                Log.e(TAG, "Failed to get media projection")
                sendFailureResult(path)
                stopSelf()
                return
            }

            // Continue with capture process
            setupImageReaderAndVirtualDisplay(path)
        } catch (e: Exception) {
            Log.e(TAG, "Error starting capture", e)
            sendFailureResult(path)
            stopSelf()
        }
    }

    private fun setupImageReaderAndVirtualDisplay(path: String) {
        try {
            // Register callback
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {  // Android 11+
                mediaProjection?.registerCallback(object : MediaProjection.Callback() {
                    override fun onStop() {
                        Log.d(TAG, "MediaProjection stopped")
                    }
                }, Handler(Looper.getMainLooper()))
            }

            val metrics = resources.displayMetrics
            val width = metrics.widthPixels
            val height = metrics.heightPixels
            val density = metrics.densityDpi

            Log.d(TAG, "Screen metrics: width=$width, height=$height, density=$density")

            imageReader = ImageReader.newInstance(width, height, android.graphics.PixelFormat.RGBA_8888, 2)

            virtualDisplay = mediaProjection?.createVirtualDisplay(
                "ScreenCapture",
                width, height, density,
                DisplayManager.VIRTUAL_DISPLAY_FLAG_AUTO_MIRROR,
                imageReader?.surface, null, Handler(Looper.getMainLooper())
            )

            if (virtualDisplay == null) {
                Log.e(TAG, "Failed to create virtual display")
                sendFailureResult(path)
                stopSelf()
                return
            }

            Log.d(TAG, "Virtual display created, waiting for image...")

            // Wait a moment for the image to be ready
            Handler(Looper.getMainLooper()).postDelayed({
                captureScreenshot(path)
            }, 500)
        } catch (e: Exception) {
            Log.e(TAG, "Error setting up capture", e)
            sendFailureResult(path)
            stopSelf()
        }
    }

    private fun captureScreenshot(path: String) {
        Log.d(TAG, "Starting screenshot capture")
        var success = false

        try {
            val image = imageReader?.acquireLatestImage()

            if (image != null) {
                val planes = image.planes
                val buffer = planes[0].buffer
                val pixelStride = planes[0].pixelStride
                val rowStride = planes[0].rowStride
                val rowPadding = rowStride - pixelStride * (resources.displayMetrics.widthPixels)

                val bitmap = Bitmap.createBitmap(
                    resources.displayMetrics.widthPixels + rowPadding / pixelStride,
                    resources.displayMetrics.heightPixels,
                    Bitmap.Config.ARGB_8888
                )
                bitmap.copyPixelsFromBuffer(buffer)

                try {
                    val file = File(path)
                    // Check if parent folder exists, create it if not
                    val parent = file.parentFile
                    if (parent != null && !parent.exists()) {
                        parent.mkdirs()
                    }

                    Log.d(TAG, "Saving screenshot to: $path")
                    Log.d(TAG, "File can write: ${file.canWrite()}")
                    Log.d(TAG, "Parent exists: ${parent?.exists()}")

                    val out = FileOutputStream(file)
                    bitmap.compress(Bitmap.CompressFormat.PNG, 100, out)
                    out.flush()
                    out.close()

                    success = true
                    Log.d(TAG, "Screenshot saved successfully")
                } catch (e: Exception) {
                    Log.e(TAG, "Error saving screenshot", e)
                }

                bitmap.recycle()
                image.close()
            } else {
                Log.e(TAG, "Failed to acquire image")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error during screen capture", e)
        } finally {
            // Send broadcast with result
            if (success) {
                sendSuccessResult(path)
            } else {
                sendFailureResult(path)
            }

            cleanup()
            stopSelf()
        }
    }

    private fun cleanup() {
        try {
            virtualDisplay?.release()
            imageReader?.close()
            mediaProjection?.stop()

            Log.d(TAG, "Resources cleaned up")
        } catch (e: Exception) {
            Log.e(TAG, "Error during cleanup", e)
        }
    }

    override fun onDestroy() {
        cleanup()
        Log.d(TAG, "Service destroyed")
        super.onDestroy()
    }
}