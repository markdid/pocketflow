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
import android.util.Log
import android.view.KeyEvent
import androidx.core.content.IntentCompat
import java.util.Locale

/**
 * Walk mode: the headset's play/pause button starts and stops a memo, with audio cues so the phone can stay in a
 * pocket.
 *
 * Android sends media buttons to the app that most recently played audio, so the session claims them by playing a
 * moment of silence when walk mode turns on and again after each spoken confirmation. If music is playing, the music
 * app keeps the button until PocketFlow plays something again.
 */
class HeadsetControls(private val context: Context, private val onButton: () -> Unit) {
    private var session: MediaSession? = null
    private var tts: TextToSpeech? = null
    private var ttsReady = false
    private var lastPress = 0L

    fun enable() {
        if (session != null) return
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
        tts = TextToSpeech(context) { status ->
            ttsReady = status == TextToSpeech.SUCCESS
            if (ttsReady) tts?.language = Locale.getDefault()
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
            claimMediaButtons()
            return
        }
        engine.speak(text, TextToSpeech.QUEUE_FLUSH, Bundle(), "pocketflow-${System.currentTimeMillis()}")
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
        val buttonKeys = setOf(
            KeyEvent.KEYCODE_HEADSETHOOK,
            KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE,
            KeyEvent.KEYCODE_MEDIA_PLAY,
            KeyEvent.KEYCODE_MEDIA_PAUSE,
        )
    }
}
