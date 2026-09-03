package com.pocketflow.app

import android.app.Application
import android.app.NotificationChannel
import android.app.NotificationManager
import com.pocketflow.app.data.SettingsRepository

class PocketFlowApp : Application() {
    lateinit var settings: SettingsRepository
        private set

    override fun onCreate() {
        super.onCreate()
        instance = this
        settings = SettingsRepository(this)
        seedApiKeyFromBuildConfig()
        createNotificationChannel()
    }

    private fun seedApiKeyFromBuildConfig() {
        val baked = BuildConfig.GROQ_API_KEY.trim()
        if (baked.isNotBlank() && settings.apiKey.value != baked) {
            settings.setApiKey(baked)
        }
    }

    private fun createNotificationChannel() {
        val channel = NotificationChannel(
            NOTIFICATION_CHANNEL_ID,
            getString(R.string.notification_channel_name),
            NotificationManager.IMPORTANCE_LOW,
        )
        val nm = getSystemService(NotificationManager::class.java)
        nm.createNotificationChannel(channel)
    }

    companion object {
        const val NOTIFICATION_CHANNEL_ID = "dictation"
        lateinit var instance: PocketFlowApp
            private set
    }
}
