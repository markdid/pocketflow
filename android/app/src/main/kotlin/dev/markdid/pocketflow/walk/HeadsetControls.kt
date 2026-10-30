package dev.markdid.pocketflow.walk

import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioManager
import android.media.AudioTrack
import android.media.ToneGenerator
import android.media.session.MediaSession
import android.media.session.PlaybackState
import android.os.Bundle
import android.speech.tts.TextToSpeech
import android.speech.tts.UtteranceProgressListener
import android.util.Log
import android.view.KeyEvent
import androidx.core.content.IntentCompat
import kotlinx.coroutines.delay
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.withTimeoutOrNull
import java.util.Locale
import kotlin.coroutines.resume

/**
 * Walk mode: the headset's play/pause button starts and stops a memo, with audio cues so the phone can stay in a
 * pocket.
 *
 * Android sends media buttons to the app that most recently played audio, so the session claims them by playing a
 * moment of silence when walk mode turns on and again after each spoken confirmation. If music is playing, the music
 * app keeps the button until PocketFlow plays something again.
 */
class HeadsetControls(
    private val context: Context,
    /** False for speech only: no media session, so a watch doesn't open its media remote and no button stops a memo. */
    private val claimButtons: Boolean = true,
    private val onButton: () -> Unit = {},
) {
    private var session: MediaSession? = null
    private var tts: TextToSpeech? = null
    private var ttsReady = false
    private var lastPress = 0L

    fun enable() {
        if (session != null || tts != null) return
        tts = TextToSpeech(context) { status ->
            ttsReady = status == TextToSpeech.SUCCESS
            if (ttsReady) tts?.language = Locale.getDefault()
        }
        if (!claimButtons) return
        session = MediaSession(context, "PocketFlow walk mode").apply {
            setCallback(object : MediaSession.Callback() {
                override fun onMediaButtonEvent(intent: Intent): Boolean {
                    val event = IntentCompat.getParcelableExtra(intent, Intent.EXTRA_KEY_EVENT, KeyEvent::class.java)
                        ?: return false
                    if (event.keyCode !in buttonKeys) return false
                    if (event.action == KeyEvent.ACTION_DOWN && event.repeatCount == 0) press()
                    return true
                }

                // Some headsets and Bluetooth stacks deliver play/pause as transport controls instead of key events.
                override fun onPlay() = press()
                override fun onPause() = press()
            })
            setPlaybackState(
                PlaybackState.Builder()
                    .setActions(PlaybackState.ACTION_PLAY_PAUSE or PlaybackState.ACTION_PLAY or PlaybackState.ACTION_PAUSE)
                    .setState(PlaybackState.STATE_PLAYING, 0, 1f)
                    .build(),
            )
            isActive = true
        }
        claimMediaButtons()
    }

    fun disable() {
        session?.run {
            isActive = false
            release()
        }
        session = null
        tts?.shutdown()
        tts = null
        ttsReady = false
    }

    private fun press() {
        // Both the key event and the transport callback can fire for one press.
        val now = System.currentTimeMillis()
        if (now - lastPress < DEBOUNCE_MS) return
        lastPress = now
        Log.i(TAG, "headset button")
        onButton()
    }

    fun startCue() = tone(ToneGenerator.TONE_PROP_BEEP)

    fun stopCue() = tone(ToneGenerator.TONE_PROP_ACK)

    /** Spoken result ("Memo saved"), which also keeps PocketFlow first in line for the next button press. */
    fun say(text: String) {
        val engine = tts
        if (engine == null || !ttsReady) {
            if (claimButtons) claimMediaButtons()
            return
        }
        engine.speak(text, TextToSpeech.QUEUE_FLUSH, Bundle(), "pocketflow-${System.currentTimeMillis()}")
    }

    /**
     * Speaks [text] over call audio, for when the headset mic is already open (a memo started from the watch), and
     * returns once it has been said. Gives up after a few seconds.
     */
    suspend fun announce(text: String) {
        withTimeoutOrNull(ANNOUNCE_TIMEOUT_MS) {
            while (!ttsReady) delay(50)
            val engine = tts ?: return@withTimeoutOrNull
            val id = "pocketflow-${System.currentTimeMillis()}"
            suspendCancellableCoroutine { done ->
                engine.setOnUtteranceProgressListener(object : UtteranceProgressListener() {
                    override fun onStart(utteranceId: String?) = Unit

                    override fun onDone(utteranceId: String?) {
                        if (utteranceId == id && done.isActive) done.resume(Unit)
                    }

                    @Deprecated("Deprecated in Java")
                    override fun onError(utteranceId: String?) {
                        if (utteranceId == id && done.isActive) done.resume(Unit)
                    }
                })
                engine.setAudioAttributes(callAudio)
                engine.speak(text, TextToSpeech.QUEUE_FLUSH, Bundle(), id)
            }
        }
        tts?.setAudioAttributes(mediaAudio)
    }

    private fun tone(type: Int) {
        runCatching {
            val generator = ToneGenerator(AudioManager.STREAM_MUSIC, 80)
            generator.startTone(type, 150)
            android.os.Handler(context.mainLooper).postDelayed({ generator.release() }, 400)
        }
    }

    /** Plays 200 ms of silence so Android treats PocketFlow as the active media app. */
    fun claimMediaButtons() {
        runCatching {
            val sampleRate = 16_000
            val samples = ShortArray(sampleRate / 5)
            val track = AudioTrack.Builder()
                .setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_MEDIA)
                        .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
                        .build(),
                )
                .setAudioFormat(
                    AudioFormat.Builder()
                        .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
                        .setSampleRate(sampleRate)
                        .setChannelMask(AudioFormat.CHANNEL_OUT_MONO)
                        .build(),
                )
                .setTransferMode(AudioTrack.MODE_STATIC)
                .setBufferSizeInBytes(samples.size * 2)
                .build()
            track.write(samples, 0, samples.size)
            track.play()
            android.os.Handler(context.mainLooper).postDelayed({ track.release() }, 500)
        }
    }

    private companion object {
        const val TAG = "PocketFlow"
        const val DEBOUNCE_MS = 600L
        const val ANNOUNCE_TIMEOUT_MS = 4_000L
        val callAudio: AudioAttributes = AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_VOICE_COMMUNICATION)
            .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
            .build()
        val mediaAudio: AudioAttributes = AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_MEDIA)
            .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
            .build()
        val buttonKeys = setOf(
            KeyEvent.KEYCODE_HEADSETHOOK,
            KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE,
            KeyEvent.KEYCODE_MEDIA_PLAY,
            KeyEvent.KEYCODE_MEDIA_PAUSE,
        )
    }
}
