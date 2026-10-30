package dev.markdid.pocketflow.wear

import android.app.Application
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.os.VibrationEffect
import android.os.VibratorManager

class WatchApp : Application() {
    override fun onCreate() {
        super.onCreate()
        getSystemService(NotificationManager::class.java).createNotificationChannel(
            NotificationChannel(CHANNEL, "Recording", NotificationManager.IMPORTANCE_LOW),
        )
        // A recording still in progress when the process died can't be finished or sent.
        PhoneSync.outbox(this).listFiles { file -> file.name.endsWith(".recording") }?.forEach { it.delete() }
        WatchStore.load(this)
    }

    companion object {
        const val CHANNEL = "recording"

        fun buzz(context: Context, pattern: LongArray) {
            context.getSystemService(VibratorManager::class.java)?.defaultVibrator
                ?.vibrate(VibrationEffect.createWaveform(pattern, -1))
        }
    }
}
