// ไฟล์: android/app/src/main/kotlin/com/example/screentranslator/MainActivity.kt
package com.example.screentranslator

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.media.projection.MediaProjectionManager
import android.os.Build
import android.util.Log
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.yourapp.screenshot"
    private val REQUEST_MEDIA_PROJECTION = 1

    private var screenshotResult: MethodChannel.Result? = null
    private var pendingScreenshotPath: String? = null

    private val TAG = "MainActivity"

    private val screenshotReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (intent?.action == ScreenCaptureService.ACTION_SCREENSHOT_RESULT) {
                val success = intent.getBooleanExtra(ScreenCaptureService.EXTRA_SUCCESS, false)
                val path = intent.getStringExtra(ScreenCaptureService.EXTRA_PATH)

                Log.d(TAG, "Received screenshot result: success=$success, path=$path")

                screenshotResult?.success(success)
                screenshotResult = null
            }
        }
    }

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // ลงทะเบียน BroadcastReceiver ให้ถูกต้องตามเวอร์ชัน Android
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                registerReceiver(
                    screenshotReceiver,
                    IntentFilter(ScreenCaptureService.ACTION_SCREENSHOT_RESULT),
                    Context.RECEIVER_NOT_EXPORTED
                )
            } else {
                registerReceiver(screenshotReceiver, IntentFilter(ScreenCaptureService.ACTION_SCREENSHOT_RESULT))
            }
            Log.d(TAG, "BroadcastReceiver registered successfully")
        } catch (e: Exception) {
            Log.e(TAG, "Error registering BroadcastReceiver", e)
        }

        // ลงทะเบียน MethodChannel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "checkScreenshotPermission" -> {
                    result.success(false) // จะขออนุญาตทุกครั้งที่ถ่ายภาพ
                }
                "requestScreenshotPermission" -> {
                    try {
                        val mediaProjectionManager = getSystemService(Context.MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
                        startActivityForResult(
                            mediaProjectionManager.createScreenCaptureIntent(),
                            REQUEST_MEDIA_PROJECTION
                        )
                        screenshotResult = result
                        Log.d(TAG, "Requesting screenshot permission")
                    } catch (e: Exception) {
                        Log.e(TAG, "Error requesting permission", e)
                        result.error("PERMISSION_ERROR", e.message, null)
                    }
                }
                "takeScreenshot" -> {
                    val path = call.argument<String>("path")
                    if (path != null) {
                        try {
                            pendingScreenshotPath = path
                            screenshotResult = result

                            val mediaProjectionManager = getSystemService(Context.MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
                            startActivityForResult(
                                mediaProjectionManager.createScreenCaptureIntent(),
                                REQUEST_MEDIA_PROJECTION
                            )
                            Log.d(TAG, "Requesting screenshot for path: $path")
                        } catch (e: Exception) {
                            Log.e(TAG, "Error requesting screenshot", e)
                            result.error("SCREENSHOT_ERROR", e.message, null)
                        }
                    } else {
                        result.error("INVALID_ARGUMENT", "Path is required", null)
                    }
                }
                "startScreenshotService" -> {
                    val path = call.argument<String>("path")
                    if (path != null) {
                        try {
                            pendingScreenshotPath = path
                            screenshotResult = result

                            val mediaProjectionManager = getSystemService(Context.MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
                            startActivityForResult(
                                mediaProjectionManager.createScreenCaptureIntent(),
                                REQUEST_MEDIA_PROJECTION
                            )
                            Log.d(TAG, "Requesting screenshot service for path: $path")
                        } catch (e: Exception) {
                            Log.e(TAG, "Error starting screenshot service", e)
                            result.error("SERVICE_ERROR", e.message, null)
                        }
                    } else {
                        result.error("INVALID_ARGUMENT", "Path is required", null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)

        Log.d(TAG, "onActivityResult: requestCode=$requestCode, resultCode=$resultCode")

        if (requestCode == REQUEST_MEDIA_PROJECTION) {
            if (resultCode == RESULT_OK && data != null && pendingScreenshotPath != null) {
                try {
                    // ส่งเฉพาะ resultCode และ data ไปยัง Service
                    // โดยไม่สร้าง MediaProjection ในที่นี้
                    val intent = Intent(this, ScreenCaptureService::class.java).apply {
                        action = ScreenCaptureService.ACTION_START
                        putExtra(ScreenCaptureService.EXTRA_RESULT_CODE, resultCode)
                        putExtra(ScreenCaptureService.EXTRA_DATA, data)  // ส่ง data โดยตรง
                        putExtra(ScreenCaptureService.EXTRA_PATH, pendingScreenshotPath)
                    }

                    Log.d(TAG, "Starting service to take screenshot at path: $pendingScreenshotPath")

                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        startForegroundService(intent)  // ใช้ startForegroundService สำหรับ Android 8+
                    } else {
                        startService(intent)
                    }

                    screenshotResult?.success(true)
                } catch (e: Exception) {
                    Log.e(TAG, "Error starting service", e)
                    screenshotResult?.error("SERVICE_ERROR", e.message, null)
                }
            } else {
                // ผู้ใช้ปฏิเสธการให้สิทธิ์หรือมีข้อผิดพลาด
                Log.d(TAG, "Permission denied or error: resultCode=$resultCode, data=$data")
                screenshotResult?.success(false)
            }

            screenshotResult = null
            pendingScreenshotPath = null
        }
    }

    override fun onDestroy() {
        try {
            unregisterReceiver(screenshotReceiver)
            Log.d(TAG, "BroadcastReceiver unregistered")
        } catch (e: Exception) {
            Log.e(TAG, "Error unregistering receiver", e)
        }
        super.onDestroy()
    }
}