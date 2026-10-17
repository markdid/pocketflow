package dev.markdid.pocketflow.audio

import android.annotation.SuppressLint
import android.media.AudioFormat
import android.media.AudioRecord
import java.io.File
import java.io.RandomAccessFile
import java.nio.ByteBuffer
import java.nio.ByteOrder
import kotlin.concurrent.thread
import kotlin.math.sqrt

/** Records 16 kHz mono 16-bit PCM to a WAV file, which every transcription API accepts. */
class WavAudioRecorder : AudioCapture {
    @Volatile
    private var recording = false

    @Volatile
    private var level = 0f

    @Volatile
    private var totalBytes = 0L
    private var worker: Thread? = null

    override val durationMillis: Long get() = totalBytes * 1000 / (SAMPLE_RATE * 2)

    /** Recent loudness, 0..1. Drives the bubble animation and silence detection. */
    override fun level(): Float = level

    @SuppressLint("MissingPermission") // Checked before the service starts recording.
    override fun start(outputFile: File, audioSource: Int): Boolean {
        stop()
        val minBuffer = AudioRecord.getMinBufferSize(SAMPLE_RATE, CHANNEL, ENCODING)
        val bufferSize = minBuffer.coerceAtLeast(SAMPLE_RATE / 5 * 2)
        val recorder = AudioRecord(audioSource, SAMPLE_RATE, CHANNEL, ENCODING, bufferSize)
        if (recorder.state != AudioRecord.STATE_INITIALIZED) {
            recorder.release()
            return false
        }
        recording = true
        totalBytes = 0
        worker = thread(name = "pocketflow-recorder", priority = Thread.MAX_PRIORITY) {
            outputFile.parentFile?.mkdirs()
            RandomAccessFile(outputFile, "rw").use { raf ->
                raf.setLength(0)
                writeWavHeader(raf, 0) // rewritten with the real length on stop
                // Reads block until full, so small reads let stop() return within 50 ms of release.
                val pcm = ByteArray(SAMPLE_RATE / 20 * 2)
                recorder.startRecording()
                try {
                    while (recording) {
                        val read = recorder.read(pcm, 0, pcm.size)
                        if (read > 0) {
                            raf.write(pcm, 0, read)
                            totalBytes += read
                            level = rms(pcm, read)
                        }
                    }
                } finally {
                    runCatching { recorder.stop() }
                    recorder.release()
                    raf.seek(0)
                    writeWavHeader(raf, totalBytes.toInt())
                    level = 0f
                }
            }
        }
        return true
    }

    override fun stop() {
        recording = false
        worker?.join(2_000)
        worker = null
    }

    private fun rms(pcm: ByteArray, length: Int): Float {
        val samples = ByteBuffer.wrap(pcm, 0, length).order(ByteOrder.LITTLE_ENDIAN).asShortBuffer()
        if (samples.remaining() == 0) return 0f
        var sum = 0.0
        while (samples.hasRemaining()) {
            val s = samples.get() / 32768.0
            sum += s * s
        }
        return (sqrt(sum / (length / 2)) * 4).coerceAtMost(1.0).toFloat()
    }

    private fun writeWavHeader(raf: RandomAccessFile, dataBytes: Int) {
        val buffer = ByteBuffer.allocate(44).order(ByteOrder.LITTLE_ENDIAN)
        buffer.put("RIFF".toByteArray())
        buffer.putInt(dataBytes + 36)
        buffer.put("WAVE".toByteArray())
        buffer.put("fmt ".toByteArray())
        buffer.putInt(16) // PCM chunk size
        buffer.putShort(1) // PCM
        buffer.putShort(1) // mono
        buffer.putInt(SAMPLE_RATE)
        buffer.putInt(SAMPLE_RATE * 2) // byte rate
        buffer.putShort(2) // block align
        buffer.putShort(16) // bits per sample
        buffer.put("data".toByteArray())
        buffer.putInt(dataBytes)
        raf.write(buffer.array())
    }

    companion object {
        const val SAMPLE_RATE = 16_000
        private const val CHANNEL = AudioFormat.CHANNEL_IN_MONO
        private const val ENCODING = AudioFormat.ENCODING_PCM_16BIT
    }
}
