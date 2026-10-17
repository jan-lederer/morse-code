package studio.dit.dit_morse

import android.content.Context
import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioTrack
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import kotlin.math.PI
import kotlin.math.sin

class MainActivity : FlutterActivity() {
    private var tone: AudioTrack? = null
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "studio.dit/device")
            .setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "load" -> result.success(getSharedPreferences("dit", Context.MODE_PRIVATE).getString("state", null))
                        "save" -> {
                            getSharedPreferences("dit", Context.MODE_PRIVATE).edit().putString("state", call.arguments as String).apply()
                            result.success(null)
                        }
                        "tone" -> { setTone(call.arguments == true); result.success(null) }
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
    private fun setTone(enabled: Boolean) {
        if (!enabled) { tone?.pause(); return }
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
    override fun onPause() { tone?.pause(); super.onPause() }
    override fun onDestroy() { tone?.release(); tone = null; super.onDestroy() }
}
