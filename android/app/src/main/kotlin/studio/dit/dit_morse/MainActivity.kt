package studio.dit.dit_morse

import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioTrack
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.os.VibrationEffect
import android.os.Vibrator
import android.net.Uri
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import kotlin.math.PI
import kotlin.math.sin

class MainActivity : FlutterActivity() {
    private var tone: AudioTrack? = null
    private var patternTrack: AudioTrack? = null
    private val patternHandler = Handler(Looper.getMainLooper())
    private var patternEnd: Runnable? = null
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "studio.dit/device")
            .setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "version" -> {
                            @Suppress("DEPRECATION")
                            val info = packageManager.getPackageInfo(packageName, 0)
                            @Suppress("DEPRECATION")
                            val build = if (Build.VERSION.SDK_INT >= 28) info.longVersionCode else info.versionCode.toLong()
                            result.success("${info.versionName} ($build)")
                        }
                        "load" -> result.success(getSharedPreferences("dit", Context.MODE_PRIVATE).getString("state", null))
                        "save" -> {
                            getSharedPreferences("dit", Context.MODE_PRIVATE).edit().putString("state", call.arguments as String).apply()
                            result.success(null)
                        }
                        "openPrivacyPolicy" -> {
                            startActivity(Intent(Intent.ACTION_VIEW, Uri.parse("https://jan-lederer.github.io/morse-code/")))
                            result.success(null)
                        }
                        "tone" -> { setTone(call.arguments == true); result.success(null) }
                        "playPattern" -> {
                            val args = call.arguments as Map<*, *>
                            result.success(playPattern(args["code"] as String, args["sound"] == true, args["vibration"] == true))
                        }
                        "stopPattern" -> { stopPattern(); result.success(null) }
                        "cancelVibration" -> {
                            (getSystemService(Context.VIBRATOR_SERVICE) as Vibrator).cancel()
                            result.success(null)
                        }
                        "vibrate" -> {
                            val vibrator = getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
                            val duration = (call.arguments as Number).toLong().coerceIn(1L, 500L)
                            if (vibrator.hasVibrator()) {
                                if (Build.VERSION.SDK_INT >= 26) vibrator.vibrate(VibrationEffect.createOneShot(duration, VibrationEffect.DEFAULT_AMPLITUDE))
                                else @Suppress("DEPRECATION") vibrator.vibrate(duration)
                            }
                            result.success(null)
                        }
                        else -> result.notImplemented()
                    }
                } catch (error: Exception) { result.error("device", error.message, null) }
            }
    }
    private fun stopPattern() {
        patternEnd?.let { patternHandler.removeCallbacks(it) }
        patternEnd = null
        patternTrack?.let { it.pause(); it.flush(); it.release() }
        patternTrack = null
        (getSystemService(Context.VIBRATOR_SERVICE) as Vibrator).cancel()
    }
    private fun playPattern(code: String, sound: Boolean, vibration: Boolean): Int {
        stopPattern()
        tone?.pause()
        val pattern = SignalPattern(code)
        if (sound) {
            val samples = pattern.samples()
            val builder = AudioTrack.Builder()
                .setAudioAttributes(AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_GAME).setContentType(AudioAttributes.CONTENT_TYPE_MUSIC).build())
                .setAudioFormat(AudioFormat.Builder().setEncoding(AudioFormat.ENCODING_PCM_16BIT).setSampleRate(SignalPattern.SAMPLE_RATE).setChannelMask(AudioFormat.CHANNEL_OUT_MONO).build())
                .setTransferMode(AudioTrack.MODE_STATIC).setBufferSizeInBytes(samples.size * 2)
            if (Build.VERSION.SDK_INT >= 26) builder.setPerformanceMode(AudioTrack.PERFORMANCE_MODE_LOW_LATENCY)
            patternTrack = builder.build()
            check(patternTrack!!.write(samples, 0, samples.size) == samples.size) { "Incomplete signal buffer" }
        }
        // Preparation is complete before either device starts its timeline. The
        // leading zeros let the audio output wake up before the first full dot.
        val started = SystemClock.uptimeMillis()
        patternTrack?.play()
        if (vibration) {
            val vibrator = getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
            if (vibrator.hasVibrator()) {
                val timings = pattern.timings
                timings[0] = (timings[0] - (SystemClock.uptimeMillis() - started)).coerceAtLeast(0)
                if (Build.VERSION.SDK_INT >= 26) vibrator.vibrate(VibrationEffect.createWaveform(timings, -1))
                else @Suppress("DEPRECATION") vibrator.vibrate(timings, -1)
            }
        }
        patternEnd = Runnable { stopPattern() }
        patternHandler.postDelayed(patternEnd!!, (pattern.durationMs + 100 - (SystemClock.uptimeMillis() - started)).coerceAtLeast(0))
        return (SignalPattern.LEAD_MS - (SystemClock.uptimeMillis() - started)).coerceAtLeast(0).toInt()
    }
    private fun setTone(enabled: Boolean) {
        if (!enabled) { tone?.pause(); return }
        stopPattern()
        if (tone == null) {
            val samples = ShortArray(2205) { i -> (sin(2 * PI * 620 * i / 22050) * 4200).toInt().toShort() }
            tone = AudioTrack.Builder()
                .setAudioAttributes(AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_GAME).setContentType(AudioAttributes.CONTENT_TYPE_MUSIC).build())
                .setAudioFormat(AudioFormat.Builder().setEncoding(AudioFormat.ENCODING_PCM_16BIT).setSampleRate(22050).setChannelMask(AudioFormat.CHANNEL_OUT_MONO).build())
                .setTransferMode(AudioTrack.MODE_STATIC).setBufferSizeInBytes(samples.size * 2).build()
            tone!!.write(samples, 0, samples.size)
            tone!!.setLoopPoints(0, samples.size, -1)
        }
        tone?.play()
    }
    override fun onPause() { stopPattern(); tone?.pause(); super.onPause() }
    override fun onDestroy() { stopPattern(); tone?.release(); tone = null; super.onDestroy() }
}
