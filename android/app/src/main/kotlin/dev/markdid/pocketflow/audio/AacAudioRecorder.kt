package dev.markdid.pocketflow.audio

import android.annotation.SuppressLint
import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaCodec
import android.media.MediaCodecInfo
import android.media.MediaFormat
import android.media.MediaMuxer
import android.util.Log
import java.io.File
import java.nio.ByteBuffer
import java.nio.ByteOrder
import kotlin.concurrent.thread
import kotlin.math.sqrt

/**
 * Records 16 kHz mono speech and encodes it to 32 kbps AAC while recording, so the upload is about 8× smaller than
 * WAV (a 14 s dictation is ~55 KB instead of ~450 KB) and stopping only has to flush the last few milliseconds.
 * AudioRecord starts instantly, so the first word isn't clipped the way MediaRecorder's slower start can.
 */
class AacAudioRecorder : AudioCapture {
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
        val encoder = runCatching { Encoder(outputFile) }.getOrElse {
            Log.e(TAG, "couldn't start the AAC encoder", it)
            recorder.release()
            return false
        }
        recording = true
        totalBytes = 0
        worker = thread(name = "pocketflow-recorder", priority = Thread.MAX_PRIORITY) {
            // Reads block until full, so small reads let stop() return within 50 ms of release.
            val pcm = ByteArray(SAMPLE_RATE / 20 * 2)
            recorder.startRecording()
            try {
                while (recording) {
                    val read = recorder.read(pcm, 0, pcm.size)
                    if (read > 0) {
                        encoder.encode(pcm, read, presentationMicros = totalBytes * 1_000_000 / (SAMPLE_RATE * 2))
                        totalBytes += read
                        level = rms(pcm, read)
                    }
                }
            } catch (t: Throwable) {
                // An exception escaping this thread would crash the app; the audio so far is still finished below.
                Log.e(TAG, "recording failed", t)
            } finally {
                runCatching { recorder.stop() }
                recorder.release()
                encoder.finish(presentationMicros = totalBytes * 1_000_000 / (SAMPLE_RATE * 2))
                level = 0f
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

    /** PCM in, AAC in an .m4a file out. Used from the recorder thread only. */
    private class Encoder(outputFile: File) {
        private val codec: MediaCodec
        private val muxer: MediaMuxer
        private val info = MediaCodec.BufferInfo()
        private var track = -1

        init {
            outputFile.parentFile?.mkdirs()
            val format = MediaFormat.createAudioFormat(MediaFormat.MIMETYPE_AUDIO_AAC, SAMPLE_RATE, 1).apply {
                setInteger(MediaFormat.KEY_AAC_PROFILE, MediaCodecInfo.CodecProfileLevel.AACObjectLC)
                setInteger(MediaFormat.KEY_BIT_RATE, BIT_RATE)
                setInteger(MediaFormat.KEY_MAX_INPUT_SIZE, SAMPLE_RATE / 5 * 2)
            }
            codec = MediaCodec.createEncoderByType(MediaFormat.MIMETYPE_AUDIO_AAC)
            try {
                codec.configure(format, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
                codec.start()
                muxer = MediaMuxer(outputFile.absolutePath, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
            } catch (t: Throwable) {
                codec.release()
                throw t
            }
        }

        fun encode(pcm: ByteArray, length: Int, presentationMicros: Long) {
            var offset = 0
            // Never drop audio: wait for input space, draining output to free it.
            while (offset < length) {
                val index = codec.dequeueInputBuffer(10_000)
                if (index < 0) {
                    drain(endOfStream = false)
                    continue
                }
                val buffer = codec.getInputBuffer(index)!!
                buffer.clear()
                val chunk = minOf(buffer.remaining(), length - offset)
                buffer.put(pcm, offset, chunk)
                val micros = presentationMicros + offset * 1_000_000L / (SAMPLE_RATE * 2)
                codec.queueInputBuffer(index, 0, chunk, micros, 0)
                offset += chunk
            }
            drain(endOfStream = false)
        }

        fun finish(presentationMicros: Long) {
            try {
                var index = -1
                for (attempt in 0 until 100) {
                    index = codec.dequeueInputBuffer(10_000)
                    if (index >= 0) break
                    drain(endOfStream = false)
                }
                if (index >= 0) {
                    codec.queueInputBuffer(index, 0, 0, presentationMicros, MediaCodec.BUFFER_FLAG_END_OF_STREAM)
                    drain(endOfStream = true)
                }
            } catch (t: Throwable) {
                Log.w(TAG, "couldn't flush the AAC encoder", t)
            } finally {
                // stop() throws when nothing was written; the recording is discarded as too short anyway.
                if (track >= 0) runCatching { muxer.stop() }
                runCatching { muxer.release() }
                runCatching { codec.stop() }
                codec.release()
            }
        }

        private fun drain(endOfStream: Boolean) {
            // Bounded so a misbehaving codec can't hang stop(); ~2 s at most.
            for (attempt in 0 until 200) {
                val index = codec.dequeueOutputBuffer(info, if (endOfStream) 10_000 else 0)
                when {
                    index == MediaCodec.INFO_TRY_AGAIN_LATER -> if (!endOfStream) return
                    index == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED -> {
                        track = muxer.addTrack(codec.outputFormat)
                        muxer.start()
                    }
                    index >= 0 -> {
                        val data = codec.getOutputBuffer(index)!!
                        val isConfig = info.flags and MediaCodec.BUFFER_FLAG_CODEC_CONFIG != 0
                        if (!isConfig && info.size > 0 && track >= 0) muxer.writeSampleData(track, data, info)
                        codec.releaseOutputBuffer(index, false)
                        if (info.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0) return
                    }
                }
            }
        }
    }

    companion object {
        const val SAMPLE_RATE = 16_000
        private const val BIT_RATE = 32_000
        private const val TAG = "AacAudioRecorder"
        private const val CHANNEL = AudioFormat.CHANNEL_IN_MONO
        private const val ENCODING = AudioFormat.ENCODING_PCM_16BIT
    }
}
