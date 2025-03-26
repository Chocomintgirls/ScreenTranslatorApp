package com.example.screentranslator

import android.app.Application
import android.content.Intent
import android.media.projection.MediaProjection
import android.util.Log

class MyApplication : Application() {
    companion object {
        private const val TAG = "MyApplication"

        // These will store the Media Projection permission token
        // but NOT the actual MediaProjection object
        var resultCode: Int = -1
        var resultData: Intent? = null

        // Only store the token data, not the projection itself
        fun hasProjectionCredentials(): Boolean {
            val has = resultCode == -1 && resultData != null // -1 is RESULT_OK
            Log.d(TAG, "Checking projection credentials: code=$resultCode, data=${resultData != null}, result=$has")
            return has
        }

        // Save media projection credentials for later use
        fun saveProjectionCredentials(code: Int, data: Intent) {
            Log.d(TAG, "Saving projection credentials with resultCode=$code")
            resultCode = code
            resultData = Intent(data)  // Create a copy to be safe

            // No longer trying to initialize MediaProjection here
            // It must be done in a service
        }

        // Clear credentials when no longer needed
        fun clearProjectionCredentials() {
            resultCode = -1
            resultData = null
            Log.d(TAG, "Projection credentials cleared")
        }
    }
}