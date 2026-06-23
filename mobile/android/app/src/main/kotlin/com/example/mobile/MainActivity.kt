package com.example.mobile

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.Context
import android.media.AudioManager

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.mobile/audio"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "setSpeakerphoneOn") {
                val enable = call.argument<Boolean>("enable") ?: false
                val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
                try {
                    // Set mode to communication and force speakerphone route
                    audioManager.mode = if (enable) AudioManager.MODE_IN_COMMUNICATION else AudioManager.MODE_NORMAL
                    audioManager.isSpeakerphoneOn = enable
                    result.success(true)
                } catch (e: Exception) {
                    result.error("AUDIO_ERROR", e.message, null)
                }
            } else {
                result.notImplemented()
            }
        }
    }
}
