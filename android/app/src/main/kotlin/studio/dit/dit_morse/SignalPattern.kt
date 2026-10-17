package studio.dit.dit_morse

import kotlin.math.PI
import kotlin.math.min
import kotlin.math.sin

/** A single PCM buffer and matching off/on haptic waveform, including startup silence. */
internal class SignalPattern(code: String) {
    companion object {
        const val LEAD_MS = 150L
        const val SAMPLE_RATE = 22050
    }
    private val segments = mutableListOf(LEAD_MS to false)
    init {
        fun append(duration: Long, active: Boolean) {
            val last = segments.last()
            if (last.second == active) segments[segments.lastIndex] = (last.first + duration) to active
            else segments.add(duration to active)
        }
        for (symbol in code.take(200)) {
            if (symbol == '.' || symbol == '-') {
                append(if (symbol == '.') 100 else 300, true)
                append(100, false)
            } else append(if (symbol == '/') 400 else 200, false)
        }
    }
    val timings: LongArray get() = segments.map { it.first }.toLongArray()
    val durationMs: Long get() = segments.sumOf { it.first }
    fun samples(): ShortArray {
        val result = ShortArray(segments.sumOf { (it.first * SAMPLE_RATE / 1000).toInt() })
        var offset = 0
        for ((duration, active) in segments) {
            val count = (duration * SAMPLE_RATE / 1000).toInt()
            if (active) for (i in 0 until count) {
                // Two-millisecond ramps avoid clicks without filling the silent gaps.
                val envelope = min(1.0, min(i, count - 1 - i) / 44.0)
                result[offset + i] = (sin(2 * PI * 620 * i / SAMPLE_RATE) * 4200 * envelope).toInt().toShort()
            }
            offset += count
        }
        return result
    }
}
