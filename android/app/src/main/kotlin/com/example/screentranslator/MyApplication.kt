package com.example.screentranslator

import android.app.Application
import android.media.projection.MediaProjection
import android.content.Intent

class MyApplication : Application() {
    companion object {
        var mediaProjection: MediaProjection? = null
        var resultCode: Int = -1
        var resultData: Intent? = null

        fun hasProjectionPermission(): Boolean {
            return mediaProjection != null && resultData != null
        }
    }
}