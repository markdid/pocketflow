package dev.markdid.pocketflow.dictation

import android.Manifest
import android.app.Notification
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.content.pm.ServiceInfo
import android.media.MediaRecorder
import android.os.Build
import android.os.IBinder
import android.os.SystemClock
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.util.Log
import android.widget.Toast
import androidx.core.app.NotificationCompat
import androidx.core.app.ServiceCompat
import androidx.core.content.ContextCompat
import dev.markdid.pocketflow.MainActivity
import dev.markdid.pocketflow.PocketFlowApp
import dev.markdid.pocketflow.R
import dev.markdid.pocketflow.accessibility.PocketFlowAccessibilityService
import dev.markdid.pocketflow.audio.AacAudioRecorder
import dev.markdid.pocketflow.audio.AudioCapture
import dev.markdid.pocketflow.audio.BluetoothMicRouter
import dev.markdid.pocketflow.audio.MemoRecorder
import dev.markdid.pocketflow.input.TextDelivery
import dev.markdid.pocketflow.walk.HeadsetControls
import dev.markdid.pocketflow.wear.WatchRemote
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import java.io.File

/**
 * Owns recording and delivery. Stays alive as a low-importance foreground service while armed, so hotkeys, the
 * bubble, the keyboard, and the headset button can start the mic without Android's background-start limits.
 */
class DictationService : Service() {
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
    private val settings get() = PocketFlowApp.instance.settings
    private lateinit var engine: DictationEngine
    private lateinit var bluetooth: BluetoothMicRouter
    private var headset: HeadsetControls? = null

    private var recorder: AudioCapture? = null
    private var audioFile: File? = null
    private var recordingMemo = false

    /** Save the active recording as audio only, without transcribing. */
    private var recordingAudioOnly = false
    private var targetApp: String? = null
    private var silenceJob: Job? = null

    /** Whether the active recording comes from a Bluetooth headset, and how often it was checked and had sound. */
    private var throughHeadset = false
    private var polledWithSound = 0

    /** Stop pressed while the headset link was still opening (a quick hold-to-talk release). */
    private var stopRequested = false

    /** A memo started from the watch's record button, recorded here through the headset; results go back to it. */
    private var watch: WatchRemote.Session? = null

    /**
     * Speech for watch memos ("Listening", "Memo saved"), kept warm between them. No media session: a Galaxy Watch
     * opens its media remote over the app for one, and a stray play/pause from it or the earbuds ended the memo.
     */
    private var watchVoice: HeadsetControls? = null

    /** Walk mode's controls, or the watch's voice, for spoken memo results. */
    private val memoVoice get() = headset ?: watchVoice

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        engine = DictationEngine(this)
        bluetooth = BluetoothMicRouter(this)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        startAsForeground()
        when (intent?.action) {
            ACTION_DISARM -> disarm()
            ACTION_TOGGLE -> toggle(memo = false)
            ACTION_TOGGLE_RECORDING -> toggleRecording()
            ACTION_WATCH_START -> startForWatch(intent)
            ACTION_WATCH_STOP -> if (intent.getStringExtra(EXTRA_ID) == watch?.id) stopAndProcess()
            ACTION_WATCH_CANCEL -> if (intent.getStringExtra(EXTRA_ID) == watch?.id) cancelWatch()
            ACTION_START -> startRecording(memo = false)
            ACTION_STOP -> stopAndProcess()
            ACTION_WALK_ON -> setWalkMode(true)
            ACTION_WALK_OFF -> setWalkMode(false)
            else -> arm()
        }
        return START_STICKY
    }

    private fun arm() {
        settings.armed = true
        if (settings.walkMode) setWalkMode(true)
        publishArmed()
        if (!DictationBus.isBusy) DictationBus.setState(DictationState.idle, "")
    }

    private fun disarm() {
        if (DictationBus.status.value.state == DictationState.listening) cancelRecording()
        setWalkMode(false)
        settings.armed = false
        publishArmed()
        DictationBus.setState(DictationState.idle, "")
        ServiceCompat.stopForeground(this, ServiceCompat.STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    private fun setWalkMode(enabled: Boolean) {
        settings.walkMode = enabled
        if (enabled) {
            settings.armed = true
            if (headset == null) headset = HeadsetControls(this) { toggle(memo = true) }.also { it.enable() }
        } else {
            headset?.disable()
            headset = null
        }
        publishArmed()
        updateNotification()
    }

    private fun publishArmed() {
        DictationBus.setArmed(settings.armed, settings.walkMode)
        DictationBus.emit(mapOf("type" to "status"))
    }

    private fun toggle(memo: Boolean) {
        when (DictationBus.status.value.state) {
            DictationState.listening -> stopAndProcess()
            DictationState.transcribing -> Unit
            else -> startRecording(memo)
        }
    }

    /**
     * The watch's record button, with headphones connected here: record the memo through the headset mic, so the
     * wrist can stay down. The earbud button or the watch finishes it.
     */
    private fun startForWatch(intent: Intent) {
        val id = intent.getStringExtra(EXTRA_ID) ?: return
        val node = intent.getStringExtra(EXTRA_NODE) ?: return
        if (DictationBus.isBusy) {
            WatchRemote.unavailable(this, node, id)
            return
        }
        watch = WatchRemote.Session(id, node)
        if (watchVoice == null) watchVoice = HeadsetControls(this, claimButtons = false).also { it.enable() }
        startRecording(memo = true)
    }

    /** The watch gave up waiting and recorded with its own mic. */
    private fun cancelWatch() {
        watch = null
        if (recorder != null) cancelRecording()
        setState(DictationState.idle, "")
    }

    /** Starts or finishes a recording that's saved without transcribing. Leaves a dictation in progress alone. */
    private fun toggleRecording() {
        val state = DictationBus.status.value.state
        when {
            state == DictationState.listening && recordingAudioOnly -> stopAndProcess()
            !DictationBus.isBusy -> startRecording(memo = false, audioOnly = true)
        }
    }

    private fun startRecording(memo: Boolean, audioOnly: Boolean = false) {
        if (DictationBus.isBusy) return
        PocketFlowAccessibilityService.finishCorrectionWatch()
        settings.armed = true
        publishArmed()

        recordingMemo = memo
        recordingAudioOnly = audioOnly
        stopRequested = false
        val textBound = !memo && !audioOnly
        targetApp = if (textBound) TextDelivery.targetApp() else null
        if (textBound) TextDelivery.prepareForRemoteDesktop(this)
        setState(
            DictationState.listening,
            when {
                audioOnly -> "Recording…"
                memo -> "Recording memo…"
                else -> "Listening…"
            },
        )
        if (!audioOnly) scope.launch { runCatching { engine.warmUp() } }

        scope.launch {
            val session = watch
            if (memo && session == null) {
                headset?.startCue()
                delay(250) // let the cue finish before the headset switches to call audio
            }
            val useHeadset = (settings.bluetoothMic || session != null) && bluetooth.activate()
            if (session != null) {
                if (!useHeadset || watch !== session) {
                    // No headset after all, or the watch stopped waiting: it records with its own mic.
                    bluetooth.deactivate()
                    if (watch === session) {
                        watch = null
                        WatchRemote.unavailable(this@DictationService, session.node, session.id)
                    }
                    setState(DictationState.idle, "")
                    return@launch
                }
            }
            val source = if (useHeadset) {
                MediaRecorder.AudioSource.VOICE_COMMUNICATION
            } else {
                MediaRecorder.AudioSource.VOICE_RECOGNITION
            }
            val capture: AudioCapture = if (memo || audioOnly) MemoRecorder(this@DictationService) else AacAudioRecorder()
            val file = File(cacheDir, "recording_${System.currentTimeMillis()}.m4a")
            if (!capture.start(file, source)) {
                bluetooth.deactivate()
                setState(DictationState.error, "Couldn't start the microphone. Is another app using it?")
                if (session != null) {
                    watch = null
                    WatchRemote.unavailable(this@DictationService, session.node, session.id)
                }
                return@launch
            }
            recorder = capture
            audioFile = file
            throughHeadset = useHeadset
            polledWithSound = 0
            levelSource = capture::level
            vibrate(longArrayOf(0, 40))
            if (session != null) {
                WatchRemote.listening(this@DictationService, session)
                // Already recording, so nothing said over it is lost; call audio's echo cancelling keeps it out.
                launch { watchVoice?.announce("Listening") }
            }
            Log.i(TAG, "recording watch=${session != null} memo=$memo audioOnly=$audioOnly headset=$useHeadset app=$targetApp")
            setState(
                DictationState.listening,
                when {
                    audioOnly && useHeadset -> "Recording with your headset mic…"
                    audioOnly -> "Recording…"
                    memo && useHeadset -> "Recording memo with your headset mic…"
                    memo -> "Recording memo…"
                    useHeadset -> "Listening through your headset…"
                    else -> "Listening…"
                },
            )
            watchForSilence(capture, memo)
            if (stopRequested) stopAndProcess()
        }
    }

    /**
     * Never record forever: an hour of 32 kbps AAC (~15 MB) stays under the API's 25 MB upload limit. In walk mode,
     * also stop once the speaker has gone quiet. Warn once if a headset has sent no sound after a few seconds,
     * without interrupting the recording.
     */
    private fun watchForSilence(capture: AudioCapture, memo: Boolean) {
        silenceJob?.cancel()
        silenceJob = scope.launch {
            val stopAfter = if (memo) settings.walkAutoStopSeconds * 1000L else 0L
            val checkHeadset = throughHeadset
            var warnedAboutSilence = false
            var heardSpeech = false
            var quietSince = 0L
            while (isActive && recorder === capture) {
                delay(200)
                if (capture.durationMillis > MAX_RECORDING_MS) break
                val level = capture.level()
                if (level > SOUND_LEVEL) polledWithSound++
                if (checkHeadset && !warnedAboutSilence && polledWithSound < 2 &&
                    capture.durationMillis >= HEADSET_WARNING_MS
                ) {
                    warnedAboutSilence = true
                    Toast.makeText(this@DictationService, "No audio heard from Bluetooth headphones", Toast.LENGTH_LONG).show()
                }
                if (stopAfter <= 0) continue
                val loud = level > SPEECH_LEVEL
                val now = System.currentTimeMillis()
                when {
                    loud -> {
                        heardSpeech = true
                        quietSince = 0
                    }
                    heardSpeech && quietSince == 0L -> quietSince = now
                    heardSpeech && now - quietSince >= stopAfter -> break
                }
            }
            if (isActive && recorder === capture) stopAndProcess()
        }
    }

    private fun stopAndProcess() {
        val capture = recorder
        if (capture == null) {
            if (DictationBus.status.value.state == DictationState.listening) stopRequested = true
            return
        }
        val file = audioFile ?: return
        val memo = recordingMemo
        val audioOnly = recordingAudioOnly
        val session = watch
        watch = null
        recorder = null
        audioFile = null
        levelSource = null
        silenceJob?.cancel()
        val durationMillis = capture.durationMillis
        val releasedAt = SystemClock.elapsedRealtime()
        capture.stop()
        val stopMillis = SystemClock.elapsedRealtime() - releasedAt
        bluetooth.deactivate()
        vibrate(longArrayOf(0, 25, 40, 25))
        if (memo) headset?.stopCue()
        session?.let { WatchRemote.stopped(this, it) }

        if (durationMillis < MIN_AUDIO_MS) {
            file.delete()
            setState(DictationState.idle, "")
            session?.let { WatchRemote.result(this, it.node, it.id, "") }
            return
        }
        // Some headsets (e.g. glasses whose mic only works through their own app) open the call-audio link but send
        // silence, and Whisper invents words for silence. Two checks with sound rule out a single click.
        if (throughHeadset && polledWithSound < 2) {
            Log.w(TAG, "headset sent no sound for $durationMillis ms")
            file.delete()
            setState(
                DictationState.error,
                "Your headset’s mic sent no sound. Try another headset, or turn off “Use my headset’s mic” in Settings.",
            )
            if (memo) memoVoice?.say("Your headset's mic isn't sending any sound.")
            session?.let { WatchRemote.result(this, it.node, it.id, "", "Your headset’s mic sent no sound.") }
            return
        }

        if (audioOnly) {
            saveRecording(file, durationMillis)
            return
        }

        setState(DictationState.transcribing, if (memo) "Writing up your memo…" else "Writing…")
        scope.launch {
            try {
                val processStarted = SystemClock.elapsedRealtime()
                val result = engine.process(file.absolutePath, targetApp, memo, durationMillis)
                val processMillis = SystemClock.elapsedRealtime() - processStarted
                val error = result["error"] as? String
                val saved = result["saved"] == true
                val text = result["text"] as? String ?: ""
                when {
                    error != null && saved -> {
                        setState(DictationState.error, error)
                        if (memo) memoVoice?.say("I couldn't transcribe that yet. The recording is saved.")
                        notifyResult(
                            NOTIFICATION_SAVED,
                            if (memo) "Memo saved, not transcribed yet" else "Dictation saved, not transcribed yet",
                            "$error Open PocketFlow and tap it in Recent to try again.",
                        )
                    }
                    error != null -> {
                        setState(DictationState.error, error)
                        if (memo) memoVoice?.say("Sorry, that memo couldn't be transcribed.")
                    }
                    text.isEmpty() -> {
                        setState(DictationState.idle, "Didn't catch that.")
                        if (memo) memoVoice?.say("I didn't catch that.")
                    }
                    memo -> finishMemo(text)
                    else -> finishDictation(text, result["warning"] as? String)
                }
                Log.i(
                    TAG,
                    "released → done in ${SystemClock.elapsedRealtime() - releasedAt} ms " +
                        "(stop $stopMillis ms, pipeline $processMillis ms, then delivery)",
                )
                if (text.isNotEmpty() || saved) DictationBus.emit(mapOf("type" to "history"))
                session?.let { WatchRemote.result(this@DictationService, it.node, it.id, text, error) }
            } catch (t: Throwable) {
                Log.e(TAG, "processing failed", t)
                setState(DictationState.error, t.message ?: "Something went wrong.")
                session?.let {
                    WatchRemote.result(this@DictationService, it.node, it.id, "", t.message ?: "Something went wrong.")
                }
            } finally {
                file.delete()
            }
        }
    }

    private fun saveRecording(file: File, durationMillis: Long) {
        setState(DictationState.idle, "")
        scope.launch {
            try {
                val error = engine.save(file.absolutePath, durationMillis)["error"] as? String
                if (error != null) setState(DictationState.error, error)
                DictationBus.emit(mapOf("type" to "history"))
            } catch (t: Throwable) {
                Log.e(TAG, "saving the recording failed", t)
                setState(DictationState.error, t.message ?: "Couldn't save the recording.")
            } finally {
                file.delete()
            }
        }
    }

    private suspend fun finishDictation(text: String, warning: String?) {
        val result = TextDelivery.deliver(this, text)
        setState(
            if (result.method == TextDelivery.Method.NONE) DictationState.error else DictationState.idle,
            result.message.ifEmpty { warning.orEmpty() },
        )
        if (result.method == TextDelivery.Method.ACCESSIBILITY || result.method == TextDelivery.Method.KEYBOARD) {
            PocketFlowAccessibilityService.watchForCorrections(text) { inserted, fieldText ->
                scope.launch { learn(inserted, fieldText) }
            }
        }
    }

    private suspend fun learn(inserted: String, fieldText: String) {
        val learned = runCatching { engine.learn(inserted, fieldText) }.getOrDefault(emptyList())
        if (learned.isEmpty()) return
        val terms = learned.mapNotNull { it["term"] as? String }
        Log.i(TAG, "learned $terms")
        DictationBus.emit(mapOf("type" to "learned", "terms" to terms))
        notifyResult(
            NOTIFICATION_LEARNED,
            "Learned ${terms.joinToString(", ")}",
            "PocketFlow will spell ${if (terms.size == 1) "it" else "these"} this way from now on. Edit in Vocabulary.",
        )
    }

    private fun finishMemo(text: String) {
        setState(DictationState.idle, "Memo saved.")
        val isEmail = text.startsWith("Hi ") || text.startsWith("Hello ") || text.startsWith("Dear ")
        memoVoice?.say(if (isEmail) "Email draft saved." else "Memo saved.")
        val share = Intent(Intent.ACTION_SEND).setType("text/plain").putExtra(Intent.EXTRA_TEXT, text)
        val sharePending = PendingIntent.getActivity(
            this,
            REQUEST_SHARE,
            Intent.createChooser(share, "Send memo"),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        notifyResult(NOTIFICATION_MEMO, if (isEmail) "Email draft ready" else "Memo saved", text, sharePending)
    }

    private fun cancelRecording() {
        levelSource = null
        silenceJob?.cancel()
        recorder?.stop()
        recorder = null
        bluetooth.deactivate()
        audioFile?.delete()
        audioFile = null
    }

    private fun setState(state: DictationState, message: String) {
        DictationBus.setState(state, message, audioOnly = state == DictationState.listening && recordingAudioOnly)
        PocketFlowAccessibilityService.onDictationStateChanged()
        updateNotification()
    }

    private fun startAsForeground() {
        runCatching {
            ServiceCompat.startForeground(
                this,
                NOTIFICATION_ID,
                buildNotification(),
                ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE,
            )
        }.onFailure {
            // Microphone permission was revoked since the service was asked to start.
            Log.w(TAG, "startForeground failed", it)
            stopSelf()
        }
    }

    private fun updateNotification() {
        getSystemService(NotificationManager::class.java).notify(NOTIFICATION_ID, buildNotification())
    }

    private fun buildNotification(): Notification {
        val status = DictationBus.status.value
        val text = when {
            status.message.isNotEmpty() -> status.message
            settings.walkMode -> "Walk mode: press your headset button to record a memo."
            else -> "Ready. Use the bubble, keyboard, or hotkey to dictate."
        }
        val listening = status.state == DictationState.listening
        return NotificationCompat.Builder(this, PocketFlowApp.CHANNEL_SERVICE)
            .setContentTitle("PocketFlow")
            .setContentText(text)
            .setSmallIcon(R.drawable.ic_stat_mic)
            .setContentIntent(activityIntent())
            .addAction(0, if (listening) "Finish" else "Dictate", serviceIntent(ACTION_TOGGLE, 1))
            .addAction(0, if (settings.walkMode) "Walk mode off" else "Walk mode", serviceIntent(if (settings.walkMode) ACTION_WALK_OFF else ACTION_WALK_ON, 2))
            .addAction(0, "Turn off", serviceIntent(ACTION_DISARM, 3))
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setSilent(true)
            .build()
    }

    private fun notifyResult(id: Int, title: String, text: String, action: PendingIntent? = null) {
        val builder = NotificationCompat.Builder(this, PocketFlowApp.CHANNEL_RESULTS)
            .setContentTitle(title)
            .setContentText(text)
            .setStyle(NotificationCompat.BigTextStyle().bigText(text))
            .setSmallIcon(R.drawable.ic_stat_mic)
            .setContentIntent(activityIntent())
            .setAutoCancel(true)
        if (action != null) builder.addAction(0, "Share", action)
        getSystemService(NotificationManager::class.java).notify(id, builder.build())
    }

    private fun activityIntent() = PendingIntent.getActivity(
        this,
        0,
        Intent(this, MainActivity::class.java),
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
    )

    private fun serviceIntent(action: String, requestCode: Int) = PendingIntent.getService(
        this,
        requestCode,
        Intent(this, DictationService::class.java).setAction(action),
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
    )

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
        cancelRecording()
        headset?.disable()
        watchVoice?.disable()
        scope.cancel()
        engine.destroy()
        DictationBus.setArmed(false, false)
        super.onDestroy()
    }

    companion object {
        private const val TAG = "PocketFlow"
        private const val ACTION_DISARM = "dev.markdid.pocketflow.DISARM"
        private const val ACTION_TOGGLE = "dev.markdid.pocketflow.TOGGLE"
        private const val ACTION_TOGGLE_RECORDING = "dev.markdid.pocketflow.TOGGLE_RECORDING"
        private const val ACTION_WATCH_START = "dev.markdid.pocketflow.WATCH_START"
        private const val ACTION_WATCH_STOP = "dev.markdid.pocketflow.WATCH_STOP"
        private const val ACTION_WATCH_CANCEL = "dev.markdid.pocketflow.WATCH_CANCEL"
        private const val EXTRA_ID = "id"
        private const val EXTRA_NODE = "node"
        private const val ACTION_START = "dev.markdid.pocketflow.START"
        private const val ACTION_STOP = "dev.markdid.pocketflow.STOP"
        private const val ACTION_WALK_ON = "dev.markdid.pocketflow.WALK_ON"
        private const val ACTION_WALK_OFF = "dev.markdid.pocketflow.WALK_OFF"
        private const val NOTIFICATION_ID = 42
        private const val NOTIFICATION_MEMO = 43
        private const val NOTIFICATION_LEARNED = 44
        private const val NOTIFICATION_SAVED = 45
        private const val REQUEST_SHARE = 10
        private const val MIN_AUDIO_MS = 400L
        private const val MAX_RECORDING_MS = 60 * 60 * 1000L
        /** Warn once after a quiet start, while leaving the microphone running. */
        private const val HEADSET_WARNING_MS = 4_000L
        private const val SPEECH_LEVEL = 0.08f

        /** Well under speech, well over a headset link that carries silence (about -80 dBFS). */
        private const val SOUND_LEVEL = 0.01f

        /** Loudness of the active recording (0..1), for the orb animations; null when not recording. */
        @Volatile
        var levelSource: (() -> Float)? = null
            private set

        fun arm(context: Context) = send(context, null)
        fun disarm(context: Context) = send(context, ACTION_DISARM)
        fun toggle(context: Context) = send(context, ACTION_TOGGLE)
        fun toggleRecording(context: Context) = send(context, ACTION_TOGGLE_RECORDING)
        fun startForWatch(context: Context, id: String, node: String) =
            send(context, ACTION_WATCH_START) { putExtra(EXTRA_ID, id).putExtra(EXTRA_NODE, node) }
        fun stopForWatch(context: Context, id: String) = send(context, ACTION_WATCH_STOP) { putExtra(EXTRA_ID, id) }
        fun cancelForWatch(context: Context, id: String) = send(context, ACTION_WATCH_CANCEL) { putExtra(EXTRA_ID, id) }
        fun start(context: Context) = send(context, ACTION_START)
        fun stop(context: Context) = send(context, ACTION_STOP)
        fun setWalkMode(context: Context, enabled: Boolean) = send(context, if (enabled) ACTION_WALK_ON else ACTION_WALK_OFF)

        /** After a reboot or app update the accessibility service reconnects first; bring the service back. */
        fun restoreIfArmed(context: Context) {
            if (PocketFlowApp.instance.settings.armed) send(context, null)
        }

        private fun send(context: Context, action: String?, extras: Intent.() -> Unit = {}) {
            val intent = Intent(context, DictationService::class.java).setAction(action).apply(extras)
            // A microphone foreground service can't start without the permission, so ask in the app first.
            if (ContextCompat.checkSelfPermission(context, Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED) {
                if (action == ACTION_DISARM) context.stopService(intent)
                DictationBus.setState(DictationState.error, "Open PocketFlow and allow the microphone first.")
                return
            }
            runCatching { ContextCompat.startForegroundService(context, intent) }
                .onFailure { Log.w(TAG, "couldn't start dictation service", it) }
        }
    }
}
