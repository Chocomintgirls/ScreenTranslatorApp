// ไฟล์: android/app/src/main/kotlin/com/example/screentranslator/MyApplication.kt
package com.example.screentranslator

import android.app.Application
import android.media.projection.MediaProjection

class MyApplication : Application() {
    companion object {
        var mediaProjection: MediaProjection? = null
        var resultCode: Int = -1
        var resultData: Intent? = null

        // ใช้เพื่อเช็คว่ามีสิทธิ์หรือไม่
        fun hasProjectionPermission(): Boolean {
            return mediaProjection != null && resultData != null
        }
    }
}