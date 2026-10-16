package dev.markdid.pocketflow.audio

import android.content.Context
import android.media.MediaRecorder
import android.os.Build
import android.os.SystemClock
import java.io.File

/**
 * Records memos as 32 kbps AAC (~0.25 MB a minute), so an hour-long walk stays well under the 25 MB upload limit
 * that a WAV file would hit after about 13 minutes.
 */
class MemoRecorder(private val context: Context) : AudioCapture {
    private var recorder: MediaRecorder? = null
    private var startedAt = 0L

    override val durationMillis: Long
        get() = if (startedAt == 0L) 0 else SystemClock.elapsedRealtime() - startedAt

    override fun level(): Float = runCatching { (recorder?.maxAmplitude ?: 0) / 12_000f }
        .getOrDefault(0f)
        .coerceIn(0f, 1f)

    override fun start(outputFile: File, audioSource: Int): Boolean {
        stop()
        outputFile.parentFile?.mkdirs()
        val created = if (Build.VERSION.SDK_INT >= 31) MediaRecorder(context) else @Suppress("DEPRECATION") MediaRecorder()
        return try {
            created.apply {
                setAudioSource(audioSource)
                setOutputFormat(MediaRecorder.OutputFormat.MPEG_4)
                setAudioEncoder(MediaRecorder.AudioEncoder.AAC)
                setAudioChannels(1)
                setAudioSamplingRate(16_000)
                setAudioEncodingBitRate(32_000)
                setOutputFile(outputFile.absolutePath)
                prepare()
                start()
            }
            recorder = created
            startedAt = SystemClock.elapsedRealtime()
            true
        } catch (t: Throwable) {
            created.release()
            false
        }
    }

    override fun stop() {
        val current = recorder ?: return
        recorder = null
        runCatching { current.stop() }
        current.release()
    }
}

/** Common surface for the dictation (WAV) and memo (AAC) recorders. */
interface AudioCapture {
    val durationMillis: Long
    fun level(): Float
    fun start(outputFile: File, audioSource: Int): Boolean
    fun stop()
}
