package dev.markdid.pocketflow.wear

import android.app.Notification
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.media.MediaRecorder
import android.os.IBinder
import android.os.SystemClock
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.app.ServiceCompat
import androidx.core.content.ContextCompat
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import java.io.File

/**
 * Records a memo as 32 kbps AAC, the same format as the phone's memos, then moves it to the outbox and sends it.
 * A foreground service so recording carries on when the watch returns to its face.
 */
class RecordingService : Service() {
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
    private var recorder: MediaRecorder? = null
    private var file: File? = null
    private var id = ""
    private var startedAt = 0L
    private var limit: Job? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_START -> start()
            ACTION_STOP -> stop()
        }
        return START_NOT_STICKY
    }

    private fun start() {
        ServiceCompat.startForeground(this, NOTIFICATION_ID, notification("Recording"), ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE)
        if (recorder != null) return
        id = System.currentTimeMillis().toString()
        val output = File(PhoneSync.outbox(this), "$id.recording")
        val created = MediaRecorder(this)
        try {
            created.apply {
                setAudioSource(MediaRecorder.AudioSource.VOICE_RECOGNITION)
                setOutputFormat(MediaRecorder.OutputFormat.MPEG_4)
                setAudioEncoder(MediaRecorder.AudioEncoder.AAC)
                setAudioChannels(1)
                setAudioSamplingRate(16_000)
                setAudioEncodingBitRate(32_000)
                setOutputFile(output.absolutePath)
                prepare()
                start()
            }
        } catch (t: Throwable) {
            Log.e(TAG, "couldn't start recording", t)
            created.release()
            output.delete()
            WatchStore.setLast(this, LastMemo(id, MemoPhase.Failed, "Couldn’t start the microphone."))
            finish()
            return
        }
        recorder = created
        file = output
        startedAt = SystemClock.elapsedRealtime()
        WatchStore.setRecording(startedAt)
        WatchApp.buzz(this, longArrayOf(0, 40))
        // An hour of 32 kbps AAC stays under the transcription API's 25 MB upload limit.
        limit = scope.launch {
            delay(MAX_RECORDING_MS)
            stop()
        }
    }

    private fun stop() {
        val current = recorder
        val output = file
        if (current == null || output == null) {
            finish()
            return
        }
        recorder = null
        file = null
        limit?.cancel()
        val millis = SystemClock.elapsedRealtime() - startedAt
        runCatching { current.stop() }
        current.release()
        WatchStore.setRecording(null)
        WatchApp.buzz(this, longArrayOf(0, 25, 40, 25))
        if (millis < MIN_AUDIO_MS) {
            output.delete()
            finish()
            return
        }
        output.renameTo(File(output.parentFile, "${id}_$millis.m4a"))
        WatchStore.setLast(this, LastMemo(id, MemoPhase.Queued))
        getSystemService(android.app.NotificationManager::class.java).notify(NOTIFICATION_ID, notification("Sending"))
        scope.launch {
            PhoneSync.flush(this@RecordingService)
            finish()
        }
    }

    private fun finish() {
        ServiceCompat.stopForeground(this, ServiceCompat.STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    private fun notification(text: String): Notification = NotificationCompat.Builder(this, WatchApp.CHANNEL)
        .setContentTitle("PocketFlow")
        .setContentText(text)
        .setSmallIcon(R.drawable.ic_stat_record)
        .setOngoing(true)
        .setSilent(true)
        .setContentIntent(
            PendingIntent.getActivity(this, 0, Intent(this, MainActivity::class.java), PendingIntent.FLAG_IMMUTABLE),
        )
        .addAction(
            0,
            "Stop",
            PendingIntent.getService(
                this,
                1,
                Intent(this, RecordingService::class.java).setAction(ACTION_STOP),
                PendingIntent.FLAG_IMMUTABLE,
            ),
        )
        .build()

    override fun onDestroy() {
        limit?.cancel()
        recorder?.let {
            runCatching { it.stop() }
            it.release()
        }
        recorder = null
        WatchStore.setRecording(null)
        scope.cancel()
        super.onDestroy()
    }

    companion object {
        private const val TAG = "PocketFlowWatch"
        private const val ACTION_START = "dev.markdid.pocketflow.wear.START"
        private const val ACTION_STOP = "dev.markdid.pocketflow.wear.STOP"
        private const val NOTIFICATION_ID = 1
        private const val MIN_AUDIO_MS = 400L
        private const val MAX_RECORDING_MS = 60 * 60 * 1000L

        /** Call from the foreground (the screen): a microphone service can't start from the background. */
        fun toggle(context: Context) {
            if (WatchStore.status.value.recordingSince != null) {
                context.startService(Intent(context, RecordingService::class.java).setAction(ACTION_STOP))
            } else {
                ContextCompat.startForegroundService(
                    context,
                    Intent(context, RecordingService::class.java).setAction(ACTION_START),
                )
            }
        }
    }
}
