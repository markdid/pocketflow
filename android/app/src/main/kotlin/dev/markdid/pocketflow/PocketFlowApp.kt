package dev.markdid.pocketflow

import android.app.Application
import android.app.NotificationChannel
import android.app.NotificationManager

class PocketFlowApp : Application() {
    lateinit var settings: DeviceSettings
        private set

    override fun onCreate() {
        super.onCreate()
        instance = this
        settings = DeviceSettings(this)
        val nm = getSystemService(NotificationManager::class.java)
        nm.createNotificationChannel(
            NotificationChannel(CHANNEL_SERVICE, "Dictation", NotificationManager.IMPORTANCE_LOW),
        )
        nm.createNotificationChannel(
            NotificationChannel(CHANNEL_RESULTS, "Memos and learned words", NotificationManager.IMPORTANCE_DEFAULT),
        )
    }

    companion object {
        const val CHANNEL_SERVICE = "dictation"
        const val CHANNEL_RESULTS = "results"

        lateinit var instance: PocketFlowApp
            private set
    }
}
