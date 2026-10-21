package com.decibel.decibel

import android.content.Intent
import com.ryanheise.audioservice.AudioService
import com.ryanheise.audioservice.AudioServiceActivity

class MainActivity : AudioServiceActivity() {
    override fun onDestroy() {
        super.onDestroy()
        try {
            stopService(Intent(this, AudioService::class.java))
        } catch (_: Exception) {}
    }
}
