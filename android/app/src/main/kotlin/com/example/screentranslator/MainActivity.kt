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
    private var pendingRequestType: String? = null  // Track what type of request we're processing

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

        // Register BroadcastReceiver
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

        // Register MethodChannel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "checkScreenshotPermission" -> {
                    // Check if we already have the permission saved
                    val hasPermission = MyApplication.hasProjectionCredentials()
                    Log.d(TAG, "Checking screenshot permission: $hasPermission")
                    result.success(hasPermission)
                }
                "requestScreenshotPermission" -> {
                    try {
                        pendingRequestType = "permission_only"
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
                            pendingRequestType = "take_screenshot"

                            // Check if we already have permission
                            if (MyApplication.hasProjectionCredentials()) {
                                Log.d(TAG, "Using existing permission to take screenshot")
                                startScreenshotServiceWithExistingPermission(path)
                                result.success(true)
                            } else {
                                // Need to request permission first
                                screenshotResult = result
                                val mediaProjectionManager = getSystemService(Context.MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
                                startActivityForResult(
                                    mediaProjectionManager.createScreenCaptureIntent(),
                                    REQUEST_MEDIA_PROJECTION
                                )
                                Log.d(TAG, "Requesting new permission for screenshot: $path")
                            }
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
                            pendingRequestType = "start_service"

                            // Check if we already have permission
                            if (MyApplication.hasProjectionCredentials()) {
                                Log.d(TAG, "Using existing permission to start screenshot service")
                                startScreenshotServiceWithExistingPermission(path)
                                result.success(true)
                            } else {
                                // Need to request permission first
                                screenshotResult = result
                                val mediaProjectionManager = getSystemService(Context.MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
                                startActivityForResult(
                                    mediaProjectionManager.createScreenCaptureIntent(),
                                    REQUEST_MEDIA_PROJECTION
                                )
                                Log.d(TAG, "Requesting new permission for screenshot service: $path")
                            }
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

    // Helper function to start screenshot service using existing permission
    private fun startScreenshotServiceWithExistingPermission(path: String) {
        if (!MyApplication.hasProjectionCredentials()) {
            Log.e(TAG, "No existing permission available")
            return
        }

        try {
            val intent = Intent(this, ScreenCaptureService::class.java).apply {
                action = ScreenCaptureService.ACTION_START
                putExtra(ScreenCaptureService.EXTRA_RESULT_CODE, MyApplication.resultCode)
                putExtra(ScreenCaptureService.EXTRA_DATA, MyApplication.resultData)
                putExtra(ScreenCaptureService.EXTRA_PATH, path)
                putExtra(ScreenCaptureService.EXTRA_USE_APP_PROJECTION, true)
            }

            Log.d(TAG, "Starting service with existing permission for path: $path")

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                startForegroundService(intent)
            } else {
                startService(intent)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error starting service with existing permission", e)
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)

        Log.d(TAG, "onActivityResult: requestCode=$requestCode, resultCode=$resultCode, pendingRequestType=$pendingRequestType")

        if (requestCode == REQUEST_MEDIA_PROJECTION) {
            // IMPORTANT: In Android, RESULT_OK is -1, so check for it correctly
            if (resultCode == RESULT_OK && data != null) {
                try {
                    // Log details for debugging
                    Log.d(TAG, "Permission granted, saving credentials")

                    // Save the permission for future use - no longer trying to initialize MediaProjection
                    MyApplication.saveProjectionCredentials(resultCode, data)
                    Log.d(TAG, "Credentials saved, hasProjection=${MyApplication.hasProjectionCredentials()}")

                    // Handle different request types
                    when (pendingRequestType) {
                        "permission_only" -> {
                            // Just getting permission, nothing else to do
                            Log.d(TAG, "Permission granted successfully")
                            screenshotResult?.success(true)
                        }
                        "take_screenshot", "start_service" -> {
                            if (pendingScreenshotPath != null) {
                                // Start the service to take screenshot
                                Log.d(TAG, "Starting screenshot service after permission granted")
                                startScreenshotServiceWithExistingPermission(pendingScreenshotPath!!)
                                screenshotResult?.success(true)
                            }
                        }
                    }
                } catch (e: Exception) {
                    Log.e(TAG, "Error in permission handling", e)
                    screenshotResult?.error("PERMISSION_ERROR", e.message, null)
                }
            } else {
                // User denied permission or there was an error
                Log.d(TAG, "Permission denied or error: resultCode=$resultCode")
                screenshotResult?.success(false)
            }

            screenshotResult = null
            pendingScreenshotPath = null
            pendingRequestType = null
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