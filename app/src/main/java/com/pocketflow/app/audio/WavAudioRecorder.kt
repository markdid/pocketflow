package com.pocketflow.app.audio

import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import java.io.File
import java.io.RandomAccessFile
import java.nio.ByteBuffer
import java.nio.ByteOrder
import kotlin.concurrent.thread

/**
 * Records mono 16-bit PCM at 16 kHz and writes a WAV file suitable for Groq Whisper.
 */
class WavAudioRecorder {
    @Volatile
    private var recording = false
    private var worker: Thread? = null

    fun start(outputFile: File) {
        stop()
        recording = true
        worker = thread(name = "pocketflow-recorder", priority = Thread.MAX_PRIORITY) {
            val minBuf = AudioRecord.getMinBufferSize(SAMPLE_RATE, CHANNEL, ENCODING)
            val bufferSize = minBuf.coerceAtLeast(SAMPLE_RATE)
            val recorder = AudioRecord(
                MediaRecorder.AudioSource.VOICE_RECOGNITION,
                SAMPLE_RATE,
                CHANNEL,
                ENCODING,
                bufferSize,
            )
            if (recorder.state != AudioRecord.STATE_INITIALIZED) {
                recording = false
                recorder.release()
                return@thread
            }

            outputFile.parentFile?.mkdirs()
            RandomAccessFile(outputFile, "rw").use { raf ->
                // Placeholder header; rewritten on stop.
                writeWavHeader(raf, 0)
                val pcm = ByteArray(bufferSize)
                recorder.startRecording()
                var totalBytes = 0
                try {
                    while (recording) {
                        val read = recorder.read(pcm, 0, pcm.size)
                        if (read > 0) {
                            raf.write(pcm, 0, read)
                            totalBytes += read
                        }
                    }
                } finally {
                    runCatching {
                        recorder.stop()
                    }
                    recorder.release()
                    raf.seek(0)
                    writeWavHeader(raf, totalBytes)
                }
            }
        }
    }

    fun stop() {
        recording = false
        worker?.join(2_000)
        worker = null
    }

    private fun writeWavHeader(raf: RandomAccessFile, dataBytes: Int) {
        val totalDataLen = dataBytes + 36
        val byteRate = SAMPLE_RATE * 2
        val buffer = ByteBuffer.allocate(44).order(ByteOrder.LITTLE_ENDIAN)
        buffer.put("RIFF".toByteArray())
        buffer.putInt(totalDataLen)
        buffer.put("WAVE".toByteArray())
        buffer.put("fmt ".toByteArray())
        buffer.putInt(16) // PCM chunk size
        buffer.putShort(1) // PCM format
        buffer.putShort(1) // mono
        buffer.putInt(SAMPLE_RATE)
        buffer.putInt(byteRate)
        buffer.putShort(2) // block align
        buffer.putShort(16) // bits
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
