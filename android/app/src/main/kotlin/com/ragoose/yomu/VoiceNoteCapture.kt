package com.ragoose.yomu

import android.annotation.SuppressLint
import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaCodec
import android.media.MediaCodecInfo
import android.media.MediaFormat
import android.media.MediaMuxer
import android.media.MediaRecorder
import android.media.audiofx.NoiseSuppressor
import java.io.File
import java.nio.ByteOrder
import kotlin.math.log10
import kotlin.math.max
import kotlin.math.roundToInt

/**
 * Records a voice note the way chat apps do: microphone audio is cleaned
 * ([VoiceNoteFilter]) and encoded to AAC 20 ms at a time while the reader
 * talks, so the file is finished the moment recording stops.
 *
 * Uses the phone's own microphone (never a Bluetooth headset, which would
 * record narrow-band call audio) with Android's noise suppressor when the
 * device has one.
 */
class VoiceNoteCapture(private val path: String) {
    companion object {
        const val SAMPLE_RATE = 48_000
        const val BIT_RATE = 96_000
        private const val BLOCK = 960 // 20 ms
        private const val TIMEOUT_US = 10_000L
    }

    private lateinit var record: AudioRecord
    private lateinit var codec: MediaCodec
    private lateinit var muxer: MediaMuxer
    private var suppressor: NoiseSuppressor? = null
    private var thread: Thread? = null
    private var track = -1
    private var muxing = false
    private var samples = 0L

    @Volatile private var running = false
    @Volatile private var failure: Exception? = null

    /** Loudest sample since the level was last read, 0 to 1. */
    @Volatile private var peak = 0f

    @SuppressLint("MissingPermission") // Flutter asks for the microphone first.
    fun start() {
        val minBuffer = AudioRecord.getMinBufferSize(
            SAMPLE_RATE,
            AudioFormat.CHANNEL_IN_MONO,
            AudioFormat.ENCODING_PCM_16BIT,
        )
        record = AudioRecord(
            MediaRecorder.AudioSource.MIC,
            SAMPLE_RATE,
            AudioFormat.CHANNEL_IN_MONO,
            AudioFormat.ENCODING_PCM_16BIT,
            max(minBuffer, BLOCK * 2 * 8),
        )
        if (record.state != AudioRecord.STATE_INITIALIZED) {
            record.release()
            throw IllegalStateException("The microphone is not available")
        }
        if (NoiseSuppressor.isAvailable()) {
            suppressor = runCatching {
                NoiseSuppressor.create(record.audioSessionId)?.apply { enabled = true }
            }.getOrNull()
        }

        val format = MediaFormat.createAudioFormat(MediaFormat.MIMETYPE_AUDIO_AAC, SAMPLE_RATE, 1).apply {
            setInteger(MediaFormat.KEY_AAC_PROFILE, MediaCodecInfo.CodecProfileLevel.AACObjectLC)
            setInteger(MediaFormat.KEY_BIT_RATE, BIT_RATE)
            setInteger(MediaFormat.KEY_MAX_INPUT_SIZE, BLOCK * 2 * 4)
        }
        try {
            codec = MediaCodec.createEncoderByType(MediaFormat.MIMETYPE_AUDIO_AAC)
            codec.configure(format, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
            codec.start()
            muxer = MediaMuxer(path, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
            record.startRecording()
        } catch (e: Exception) {
            releaseAll()
            throw e
        }
        running = true
        thread = Thread(::capture, "voice-note-capture").apply { start() }
    }

    /** Loudness since the last call, in dBFS (-160 for silence). */
    fun level(): Double {
        val p = peak
        peak = 0f
        return if (p <= 0f) -160.0 else 20 * log10(p.toDouble())
    }

    /** Finishes the file. Returns its length in milliseconds. */
    fun stop(): Long {
        finish()
        failure?.let { throw it }
        return samples * 1000 / SAMPLE_RATE
    }

    /** Stops and deletes the file. */
    fun cancel() {
        runCatching { finish() }
        File(path).delete()
    }

    private fun finish() {
        running = false
        runCatching { record.stop() } // Unblocks a pending read.
        thread?.join(2_000)
        releaseAll()
    }

    private fun releaseAll() {
        runCatching { suppressor?.release() }
        runCatching { record.release() }
        if (::codec.isInitialized) runCatching { codec.release() }
        if (::muxer.isInitialized) {
            if (muxing) runCatching { muxer.stop() }
            runCatching { muxer.release() }
        }
    }

    private fun capture() {
        val filter = VoiceNoteFilter(SAMPLE_RATE)
        val pcm = ShortArray(BLOCK)
        val block = FloatArray(BLOCK)
        val info = MediaCodec.BufferInfo()
        try {
            while (running) {
                val n = record.read(pcm, 0, BLOCK)
                if (n <= 0) continue
                for (i in 0 until n) block[i] = pcm[i] / 32768f
                val blockPeak = filter.process(block, n)
                if (blockPeak > peak) peak = blockPeak
                queue(block, n, endOfStream = false, info)
            }
            queue(block, 0, endOfStream = true, info)
            drain(info, untilEnd = true)
            codec.stop()
        } catch (e: Exception) {
            failure = e
            running = false
        }
    }

    private fun queue(block: FloatArray, n: Int, endOfStream: Boolean, info: MediaCodec.BufferInfo) {
        while (true) {
            val index = codec.dequeueInputBuffer(TIMEOUT_US)
            if (index >= 0) {
                val buffer = codec.getInputBuffer(index)!!
                buffer.clear()
                val shorts = buffer.order(ByteOrder.LITTLE_ENDIAN).asShortBuffer()
                for (i in 0 until n) {
                    shorts.put((block[i] * 32767f).roundToInt().coerceIn(-32768, 32767).toShort())
                }
                val timeUs = samples * 1_000_000L / SAMPLE_RATE
                val flags = if (endOfStream) MediaCodec.BUFFER_FLAG_END_OF_STREAM else 0
                codec.queueInputBuffer(index, 0, n * 2, timeUs, flags)
                samples += n
                drain(info, untilEnd = false)
                return
            }
            // The encoder is full: hand on what it has finished, then retry.
            drain(info, untilEnd = false)
        }
    }

    private fun drain(info: MediaCodec.BufferInfo, untilEnd: Boolean) {
        while (true) {
            val index = codec.dequeueOutputBuffer(info, if (untilEnd) TIMEOUT_US else 0)
            when {
                index == MediaCodec.INFO_TRY_AGAIN_LATER -> if (!untilEnd) return
                index == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED -> {
                    track = muxer.addTrack(codec.outputFormat)
                    muxer.start()
                    muxing = true
                }
                index >= 0 -> {
                    val buffer = codec.getOutputBuffer(index)!!
                    val isConfig = info.flags and MediaCodec.BUFFER_FLAG_CODEC_CONFIG != 0
                    if (!isConfig && info.size > 0 && muxing) {
                        buffer.position(info.offset)
                        buffer.limit(info.offset + info.size)
                        muxer.writeSampleData(track, buffer, info)
                    }
                    codec.releaseOutputBuffer(index, false)
                    if (info.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0) return
                }
            }
        }
    }
}
