package studio.dit.dit_morse

import java.io.DataOutputStream
import java.io.FileOutputStream
import kotlin.math.abs

fun main(args: Array<String>) {
    for ((code, expected) in listOf(
        ".-" to longArrayOf(150, 100, 100, 300, 100),
        ".." to longArrayOf(150, 100, 100, 100, 100)
    )) {
        val pattern = SignalPattern(code)
        check(pattern.timings.contentEquals(expected)) { "Incorrect haptic pattern for $code" }
        val pcm = pattern.samples()
        var offset = 0
        for ((index, duration) in expected.withIndex()) {
            val count = (duration * SignalPattern.SAMPLE_RATE / 1000).toInt()
            val window = pcm.sliceArray(offset until offset + count)
            if (index % 2 == 0) check(window.all { it.toInt() == 0 }) { "Non-silent startup/gap for $code" }
            else check(window.maxOf { abs(it.toInt()) } > 3000) { "Missing full pulse for $code" }
            offset += count
        }
        check(offset == pcm.size)
        check(pcm.contentEquals(SignalPattern(code).samples())) { "Cold and repeat PCM differ" }
    }
    val pcm = SignalPattern(".- ..").samples()
    DataOutputStream(FileOutputStream(args[0])).use { out ->
        fun intLE(value: Int) = out.writeInt(Integer.reverseBytes(value))
        fun shortLE(value: Int) = out.writeShort(java.lang.Short.reverseBytes(value.toShort()).toInt())
        out.writeBytes("RIFF"); intLE(36 + pcm.size * 2); out.writeBytes("WAVEfmt ")
        intLE(16); shortLE(1); shortLE(1); intLE(SignalPattern.SAMPLE_RATE)
        intLE(SignalPattern.SAMPLE_RATE * 2); shortLE(2); shortLE(16)
        out.writeBytes("data"); intLE(pcm.size * 2)
        for (sample in pcm) shortLE(sample.toInt())
    }
    println("Verified native PCM and haptic timings for A and I: full pulses, zero-valued startup/gaps, identical cold/repeat buffers. Exported native A/I waveform.")
}
