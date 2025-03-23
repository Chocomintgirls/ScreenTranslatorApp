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

    companion object {
        private const val TAG = "ScreenCaptureService"
        const val EXTRA_RESULT_CODE = "result_code"
        const val EXTRA_DATA = "data"
        const val EXTRA_PATH = "path"
        const val ACTION_START = "start"
        const val ACTION_STOP = "stop"

        // สำหรับส่งผลลัพธ์กลับไปยัง MainActivity
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
        Log.d("onStartCommand", "Service started")

        if (intent == null) {
            stopSelf()
            return START_NOT_STICKY
        }

        when (intent.action) {
            ACTION_START -> {
                val resultCode = intent.getIntExtra(EXTRA_RESULT_CODE, -1)
                val data = intent.getParcelableExtra<Intent>(EXTRA_DATA)
                val path = intent.getStringExtra(EXTRA_PATH)

                Log.d(TAG, "Action START received: resultCode=$resultCode, data=$data, path=$path")

                if (data != null && path != null) {
                    try {
                        startCapture(resultCode, data, path)
                    } catch (e: Exception) {
                        Log.e(TAG, "Error starting capture", e)
                        sendFailureResult(path)
                        stopSelf()
                    }
                } else {
                    Log.e(TAG, "Invalid parameters for startCapture")
                    sendFailureResult(path ?: "unknown")
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
        // สร้าง Notification Channel (จำเป็นสำหรับ Android 8+)
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

        // สร้าง Notification
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

        // เริ่ม Foreground Service
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(NOTIFICATION_ID, notification, android.content.pm.ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PROJECTION)
            Log.d(TAG, "Service started in foreground with MEDIA_PROJECTION type")
        } else {
            startForeground(NOTIFICATION_ID, notification)
            Log.d(TAG, "Service started in foreground")
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

            // ลงทะเบียน callback ก่อนเรียกใช้ createVirtualDisplay
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

            // รอสักครู่เพื่อให้ภาพพร้อม
            Handler(Looper.getMainLooper()).postDelayed({
                captureScreenshot(path)
            }, 500)
        } catch (e: Exception) {
            Log.e(TAG, "Error starting capture", e)
            sendFailureResult(path)
            stopSelf()
        }
    }

    private fun captureScreenshot(path: String) {
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
                    // ตรวจสอบว่าโฟลเดอร์แม่มีอยู่หรือไม่ถ้าไม่ให้สร้างขึ้น
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
            // ส่ง Broadcast เพื่อแจ้งผลลัพธ์
            if (success) {
                sendSuccessResult(path)
            } else {
                sendFailureResult(path)
            }

            cleanup()
            stopSelf()
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