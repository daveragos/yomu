package com.ragoose.yomu

import kotlin.math.PI
import kotlin.math.abs
import kotlin.math.cos
import kotlin.math.max
import kotlin.math.min
import kotlin.math.pow
import kotlin.math.sin
import kotlin.math.sqrt
import kotlin.math.tanh

/**
 * Settings for cleaning voice notes as they are recorded.
 *
 * Phone microphones pick up rumble from handling and breath below the
 * voice. Small phone speakers can't play it, so they distort or turn the
 * whole note down. Taking it out and keeping speech at a steady level makes
 * notes sound clear on any phone.
 */
object VoiceNoteDsp {
    /** Rumble below this goes. Voices start around 85 Hz (deep) to 165 Hz. */
    const val HIGH_PASS_HZ = 90.0

    /** Speech level to aim for, in dBFS. */
    const val TARGET_DBFS = -18.0

    /** Level to start at before any speech has been heard. */
    const val START_GAIN_DB = 4.0

    /** Gain stays within these, so near-silence isn't pumped up. */
    const val MIN_GAIN_DB = -6.0
    const val MAX_GAIN_DB = 18.0

    /** Quieter blocks are pauses and don't move the level. */
    const val SPEECH_FLOOR_DBFS = -45.0

    /** How fast the level may rise and fall, in dB per second. */
    const val RISE_DB_PER_S = 6.0
    const val FALL_DB_PER_S = 10.0

    /** The level is left alone while it is within this of the target, so it doesn't wobble between syllables. */
    const val STEADY_DB = 1.0

    /** How quickly the speech level estimate follows the voice, in seconds. */
    const val LEVEL_TIME_S = 1.5

    /** Above this, peaks are rounded off smoothly instead of clipping. */
    const val LIMIT_FROM = 0.7

    fun dbToGain(db: Double) = 10.0.pow(db / 20)

    /** Leaves samples below [LIMIT_FROM] alone and bends louder ones under 1. */
    fun softLimit(v: Float): Float {
        val a = abs(v)
        if (a <= LIMIT_FROM) return v
        val room = 1 - LIMIT_FROM
        val bent = LIMIT_FROM + room * tanh((a - LIMIT_FROM) / room)
        return (if (v < 0) -bent else bent).toFloat()
    }
}

/** Second-order Butterworth high-pass filter that keeps its state across blocks. */
class HighPass(sampleRate: Int, cutoffHz: Double) {
    private val b0: Double
    private val b1: Double
    private val b2: Double
    private val a1: Double
    private val a2: Double
    private var x1 = 0.0
    private var x2 = 0.0
    private var y1 = 0.0
    private var y2 = 0.0

    init {
        val w0 = 2 * PI * cutoffHz / sampleRate
        val cosW = cos(w0)
        val alpha = sin(w0) / (2 * sqrt(0.5))
        val a0 = 1 + alpha
        b0 = (1 + cosW) / 2 / a0
        b1 = -(1 + cosW) / a0
        b2 = (1 + cosW) / 2 / a0
        a1 = -2 * cosW / a0
        a2 = (1 - alpha) / a0
    }

    fun process(x: FloatArray, n: Int = x.size) {
        for (i in 0 until n) {
            val x0 = x[i].toDouble()
            val y0 = b0 * x0 + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
            x2 = x1
            x1 = x0
            y2 = y1
            y1 = y0
            x[i] = y0.toFloat()
        }
    }
}

/**
 * Cleans voice block by block while it is recorded: takes out the rumble
 * under the voice (a steep 4th-order cut), brings speech gently to
 * [VoiceNoteDsp.TARGET_DBFS] and rounds off peaks. Nothing is left to do
 * when recording stops.
 */
class VoiceNoteFilter(private val sampleRate: Int) {
    private val low1 = HighPass(sampleRate, VoiceNoteDsp.HIGH_PASS_HZ)
    private val low2 = HighPass(sampleRate, VoiceNoteDsp.HIGH_PASS_HZ)
    private val target = VoiceNoteDsp.dbToGain(VoiceNoteDsp.TARGET_DBFS)
    private val minGain = VoiceNoteDsp.dbToGain(VoiceNoteDsp.MIN_GAIN_DB)
    private val maxGain = VoiceNoteDsp.dbToGain(VoiceNoteDsp.MAX_GAIN_DB)
    private val floorPower = VoiceNoteDsp.dbToGain(VoiceNoteDsp.SPEECH_FLOOR_DBFS).pow(2)
    private val steady = VoiceNoteDsp.dbToGain(VoiceNoteDsp.STEADY_DB)

    /** Current gain, linear. */
    var gain = VoiceNoteDsp.dbToGain(VoiceNoteDsp.START_GAIN_DB)
        private set

    /** Smoothed power of speech heard so far; negative until there is some. */
    private var speechPower = -1.0

    /** Cleans the first [n] samples of [block] in place; returns their peak afterwards. */
    fun process(block: FloatArray, n: Int = block.size): Float {
        if (n <= 0) return 0f
        low1.process(block, n)
        low2.process(block, n)

        var sum = 0.0
        for (i in 0 until n) sum += block[i].toDouble() * block[i]
        val power = sum / n
        if (power > floorPower) {
            val seconds = n.toDouble() / sampleRate
            val follow = min(1.0, seconds / VoiceNoteDsp.LEVEL_TIME_S)
            speechPower = if (speechPower < 0) power else speechPower + (power - speechPower) * follow
            val wanted = (target / sqrt(speechPower)).coerceIn(minGain, maxGain)
            if (wanted > gain * steady) {
                gain = min(wanted, gain * VoiceNoteDsp.dbToGain(VoiceNoteDsp.RISE_DB_PER_S * seconds))
            } else if (wanted < gain / steady) {
                gain = max(wanted, gain / VoiceNoteDsp.dbToGain(VoiceNoteDsp.FALL_DB_PER_S * seconds))
            }
        }

        val g = gain.toFloat()
        var peak = 0f
        for (i in 0 until n) {
            val v = VoiceNoteDsp.softLimit(block[i] * g)
            block[i] = v
            peak = max(peak, abs(v))
        }
        return peak
    }
}
