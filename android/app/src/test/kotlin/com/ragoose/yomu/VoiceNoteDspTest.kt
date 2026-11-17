package com.ragoose.yomu

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import kotlin.math.PI
import kotlin.math.abs
import kotlin.math.log10
import kotlin.math.sin
import kotlin.math.sqrt

class VoiceNoteDspTest {
    private val rate = 48_000
    private val block = 960 // 20 ms, as recorded

    private fun sine(freq: Double, amplitude: Double, seconds: Double) =
        FloatArray((rate * seconds).toInt()) { (amplitude * sin(2 * PI * freq * it / rate)).toFloat() }

    private fun db(x: FloatArray, from: Int = 0, to: Int = x.size): Double {
        var sum = 0.0
        for (i in from until to) sum += x[i].toDouble() * x[i]
        return 20 * log10(sqrt(sum / (to - from)))
    }

    /** Runs [x] through a new filter in 20 ms blocks, as the recorder does. */
    private fun record(x: FloatArray): VoiceNoteFilter {
        val filter = VoiceNoteFilter(rate)
        var i = 0
        while (i < x.size) {
            val n = minOf(block, x.size - i)
            val chunk = x.copyOfRange(i, i + n)
            filter.process(chunk, n)
            chunk.copyInto(x, i)
            i += n
        }
        return filter
    }

    private fun highPassed(freq: Double): Double {
        val x = sine(freq, 0.5, 2.0)
        val before = db(x, x.size / 2)
        val a = HighPass(rate, VoiceNoteDsp.HIGH_PASS_HZ)
        val b = HighPass(rate, VoiceNoteDsp.HIGH_PASS_HZ)
        // In blocks, to check the state carries across them.
        var i = 0
        while (i < x.size) {
            val n = minOf(block, x.size - i)
            val chunk = x.copyOfRange(i, i + n)
            a.process(chunk, n)
            b.process(chunk, n)
            chunk.copyInto(x, i)
            i += n
        }
        return db(x, x.size / 2) - before
    }

    @Test
    fun rumbleUnderTheVoiceIsCut() {
        assertTrue("40 Hz should drop a lot", highPassed(40.0) < -25)
        assertTrue("60 Hz hum should drop", highPassed(60.0) < -12)
    }

    @Test
    fun theVoiceItselfIsLeftAlone() {
        assertTrue("200 Hz kept", highPassed(200.0) > -1)
        assertTrue("1 kHz kept", highPassed(1000.0) > -0.2)
        assertTrue("4 kHz kept", highPassed(4000.0) > -0.2)
    }

    @Test
    fun quietSpeechSettlesAtTheTargetLevel() {
        // Speech-like: a 220 Hz tone at -34 dBFS, a quarter second on and off.
        val x = sine(220.0, 0.028, 8.0)
        val talking = { i: Int -> (i / (rate / 4)) % 2 == 0 }
        for (i in x.indices) if (!talking(i)) x[i] = 0f
        record(x)
        // Over the talking in the last two seconds, once the level has caught up.
        val tail = (x.size - rate * 2 until x.size).filter(talking).map { x[it] }.toFloatArray()
        assertEquals(VoiceNoteDsp.TARGET_DBFS, db(tail), 1.5)
    }

    @Test
    fun pausesDoNotPumpUpTheGain() {
        val hiss = FloatArray(rate * 3) { ((it * 7919 % 200) - 100) / 100f * 0.0005f } // about -70 dBFS
        val filter = record(hiss)
        assertEquals(VoiceNoteDsp.dbToGain(VoiceNoteDsp.START_GAIN_DB), filter.gain, 1e-9)
    }

    @Test
    fun loudSpeechIsTurnedDownAndNeverClips() {
        val x = sine(300.0, 0.95, 4.0)
        val filter = record(x)
        assertTrue(x.all { abs(it) < 1f })
        assertTrue(filter.gain < 1.0)
    }

    @Test
    fun peaksAreRoundedOffSmoothly() {
        assertEquals(0.5f, VoiceNoteDsp.softLimit(0.5f), 0f)
        assertTrue(VoiceNoteDsp.softLimit(3f) < 1f)
        assertTrue(VoiceNoteDsp.softLimit(0.9f) < VoiceNoteDsp.softLimit(1.2f))
        assertEquals(-VoiceNoteDsp.softLimit(2f), VoiceNoteDsp.softLimit(-2f), 0f)
    }
}
