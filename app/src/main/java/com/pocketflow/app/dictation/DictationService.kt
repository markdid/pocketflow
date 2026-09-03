package com.pocketflow.app.dictation

import android.app.Notification
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import androidx.core.app.NotificationCompat
import androidx.core.app.ServiceCompat
import com.pocketflow.app.MainActivity
import com.pocketflow.app.PocketFlowApp
import com.pocketflow.app.R
import com.pocketflow.app.audio.WavAudioRecorder
import com.pocketflow.app.groq.GroqTranscriber
import com.pocketflow.app.hotkey.DictationAccessibilityService
import com.pocketflow.app.input.TextDelivery
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.io.File

/**
 * Stays alive as a low-importance FGS while "armed" so Bluetooth hotkeys can toggle
 * mic capture without hitting Android 12+ background-start restrictions.
 */
class DictationService : Service() {
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
    private val recorder = WavAudioRecorder()
    private val transcriber = GroqTranscriber()
    private var audioFile: File? = null
    private var armed = false

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_ARM -> arm()
            ACTION_DISARM -> disarm()
            ACTION_TOGGLE -> toggleRecording()
            ACTION_START -> startListening()
            ACTION_STOP -> stopAndTranscribe()
            else -> arm()
        }
        return START_STICKY
    }

    private fun arm() {
        armed = true
        isArmed = true
        DictationBus.setArmed(true)
        TextDelivery.ensurePocketFlowIme(this)
        startAsForeground(READY_TEXT)
        if (DictationBus.status.value.state != DictationState.LISTENING &&
            DictationBus.status.value.state != DictationState.TRANSCRIBING
        ) {
            DictationBus.setState(DictationState.IDLE, "Armed")
        }
    }

    private fun disarm() {
        if (DictationBus.status.value.state == DictationState.LISTENING) {
            recorder.stop()
            audioFile?.delete()
            audioFile = null
        }
        armed = false
        isArmed = false
        DictationBus.setArmed(false)
        DictationBus.setState(DictationState.IDLE, "Disarmed")
        ServiceCompat.stopForeground(this, ServiceCompat.STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    private fun toggleRecording() {
        if (!armed) {
            arm()
            startListening()
            return
        }
        when (DictationBus.status.value.state) {
            DictationState.LISTENING -> stopAndTranscribe()
            DictationState.TRANSCRIBING -> Unit
            else -> startListening()
        }
    }

    private fun startListening() {
        if (DictationBus.status.value.state == DictationState.LISTENING ||
            DictationBus.status.value.state == DictationState.TRANSCRIBING
        ) {
            return
        }

        val apiKey = PocketFlowApp.instance.settings.apiKey.value
        if (apiKey.isBlank()) {
            DictationBus.setState(DictationState.ERROR, "Set your Groq API key in PocketFlow first.")
            return
        }

        if (!armed) arm()
        // Prefer PocketFlow IME so RustDesk/local fields get a live InputConnection.
        TextDelivery.ensurePocketFlowIme(this)
        updateNotification(getString(R.string.notification_listening))
        vibrate(longArrayOf(0, 40))

        audioFile = File(cacheDir, "dictation_${System.currentTimeMillis()}.wav")
        recorder.start(audioFile!!)
        DictationBus.setState(
            DictationState.LISTENING,
            "Listening — release to finish, or double-tap to latch",
        )
    }

    private fun stopAndTranscribe() {
        if (DictationBus.status.value.state != DictationState.LISTENING) return

        recorder.stop()
        vibrate(longArrayOf(0, 25, 40, 25))
        updateNotification(getString(R.string.notification_transcribing))
        DictationBus.setState(DictationState.TRANSCRIBING, "Transcribing with Groq…")

        val file = audioFile
        val apiKey = PocketFlowApp.instance.settings.apiKey.value
        val language = PocketFlowApp.instance.settings.language.value

        scope.launch {
            try {
                val text = withContext(Dispatchers.IO) {
                    requireNotNull(file) { "No audio captured" }
                    transcriber.transcribe(apiKey, file, language)
                }
                deliverText(text)
            } catch (t: Throwable) {
                DictationBus.setState(
                    DictationState.ERROR,
                    t.message ?: "Transcription failed",
                )
                if (armed) {
                    updateNotification(READY_TEXT)
                }
            } finally {
                file?.delete()
                audioFile = null
            }
        }
    }

    private fun deliverText(text: String) {
        val result = TextDelivery.deliver(this, text)
        DictationBus.setState(
            DictationState.IDLE,
            result.message,
            lastTranscript = text,
        )
        if (armed) updateNotification(READY_TEXT)
    }

    private fun startAsForeground(content: String) {
        val notification = buildNotification(content)
        if (Build.VERSION.SDK_INT >= 34) {
            ServiceCompat.startForeground(
                this,
                NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE,
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    private fun updateNotification(content: String) {
        val nm = getSystemService(NOTIFICATION_SERVICE) as android.app.NotificationManager
        nm.notify(NOTIFICATION_ID, buildNotification(content))
    }

    private fun buildNotification(content: String): Notification {
        val open = PendingIntent.getActivity(
            this,
            0,
            Intent(this, MainActivity::class.java),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val toggle = PendingIntent.getService(
            this,
            1,
            Intent(this, DictationService::class.java).setAction(ACTION_TOGGLE),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val disarm = PendingIntent.getService(
            this,
            2,
            Intent(this, DictationService::class.java).setAction(ACTION_DISARM),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        return NotificationCompat.Builder(this, PocketFlowApp.NOTIFICATION_CHANNEL_ID)
            .setContentTitle("PocketFlow")
            .setContentText(content)
            .setSmallIcon(R.drawable.ic_launcher_foreground)
            .setContentIntent(open)
            .addAction(0, "Dictate", toggle)
            .addAction(0, "Disarm", disarm)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setSilent(true)
            .build()
    }

    private fun vibrate(pattern: LongArray) {
        val vibrator = if (Build.VERSION.SDK_INT >= 31) {
            getSystemService(VibratorManager::class.java).defaultVibrator
        } else {
            @Suppress("DEPRECATION")
            getSystemService(Vibrator::class.java)
        }
        vibrator?.vibrate(VibrationEffect.createWaveform(pattern, -1))
    }

    override fun onDestroy() {
        recorder.stop()
        armed = false
        isArmed = false
        DictationBus.setArmed(false)
        scope.cancel()
        super.onDestroy()
    }

    companion object {
        const val ACTION_ARM = "com.pocketflow.app.action.ARM"
        const val ACTION_DISARM = "com.pocketflow.app.action.DISARM"
        const val ACTION_TOGGLE = "com.pocketflow.app.action.TOGGLE"
        const val ACTION_START = "com.pocketflow.app.action.START"
        const val ACTION_STOP = "com.pocketflow.app.action.STOP"
        private const val NOTIFICATION_ID = 42

        @Volatile
        var isArmed: Boolean = false
            private set

        fun arm(context: Context) {
            context.startForegroundService(
                Intent(context, DictationService::class.java).setAction(ACTION_ARM),
            )
        }

        fun disarm(context: Context) {
            context.startService(
                Intent(context, DictationService::class.java).setAction(ACTION_DISARM),
            )
        }

        fun toggle(context: Context) {
            val intent = Intent(context, DictationService::class.java).setAction(ACTION_TOGGLE)
            if (isArmed) {
                context.startService(intent)
            } else {
                runCatching { context.startForegroundService(intent) }
            }
        }

        fun start(context: Context) {
            val intent = Intent(context, DictationService::class.java).setAction(ACTION_START)
            if (isArmed) context.startService(intent)
            else runCatching { context.startForegroundService(intent) }
        }

        fun stop(context: Context) {
            context.startService(
                Intent(context, DictationService::class.java).setAction(ACTION_STOP),
            )
        }

        private const val READY_TEXT =
            "Ready — hold Caps Lock; double-tap to latch"
    }
}
