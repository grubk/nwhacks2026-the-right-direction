package com.therightdirection

import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.content.Context
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    
    private val HAPTICS_CHANNEL = "com.therightdirection/haptics"
    
    private var vibrator: Vibrator? = null
    
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Initialize vibrator
        vibrator = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val vibratorManager = getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager
            vibratorManager.defaultVibrator
        } else {
            @Suppress("DEPRECATION")
            getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
        }
        
        // Setup Haptics channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, HAPTICS_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "hasVibrator" -> {
                        result.success(vibrator?.hasVibrator() ?: false)
                    }
                    "hasAmplitudeControl" -> {
                        result.success(
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                                vibrator?.hasAmplitudeControl() ?: false
                            } else {
                                false
                            }
                        )
                    }
                    "vibrate" -> {
                        val duration = (call.argument<Number>("duration") ?: 100).toLong()
                        val amplitude = (call.argument<Number>("amplitude") ?: 255).toInt()
                        vibrate(duration, amplitude, result)
                    }
                    "vibratePattern" -> {
                        @Suppress("UNCHECKED_CAST")
                        val pattern = call.argument<List<Long>>("pattern") ?: emptyList()
                        @Suppress("UNCHECKED_CAST")
                        val amplitudes = call.argument<List<Int>>("amplitudes")
                        val repeat = call.argument<Int>("repeat") ?: -1
                        vibratePattern(pattern.toLongArray(), amplitudes?.toIntArray(), repeat, result)
                    }
                    "playWaveform" -> {
                        @Suppress("UNCHECKED_CAST")
                        val timings = call.argument<List<Long>>("timings") ?: emptyList()
                        @Suppress("UNCHECKED_CAST")
                        val amplitudes = call.argument<List<Int>>("amplitudes") ?: emptyList()
                        val repeat = call.argument<Int>("repeat") ?: -1
                        playWaveform(timings.toLongArray(), amplitudes.toIntArray(), repeat, result)
                    }
                    "playPredefinedEffect" -> {
                        val effectId = call.argument<Int>("effectId") ?: 0
                        playPredefinedEffect(effectId, result)
                    }
                    "cancel" -> {
                        vibrator?.cancel()
                        result.success(true)
                    }
                    else -> {
                        result.notImplemented()
                    }
                }
            }
    }
    
    private fun vibrate(duration: Long, amplitude: Int, result: MethodChannel.Result) {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val effect = VibrationEffect.createOneShot(duration, amplitude)
                vibrator?.vibrate(effect)
            } else {
                @Suppress("DEPRECATION")
                vibrator?.vibrate(duration)
            }
            result.success(true)
        } catch (e: Exception) {
            result.error("VIBRATION_FAILED", e.message, null)
        }
    }
    
    private fun vibratePattern(
        pattern: LongArray,
        amplitudes: IntArray?,
        repeat: Int,
        result: MethodChannel.Result
    ) {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && amplitudes != null) {
                val effect = VibrationEffect.createWaveform(pattern, amplitudes, repeat)
                vibrator?.vibrate(effect)
            } else {
                @Suppress("DEPRECATION")
                vibrator?.vibrate(pattern, repeat)
            }
            result.success(true)
        } catch (e: Exception) {
            result.error("VIBRATION_FAILED", e.message, null)
        }
    }
    
    private fun playWaveform(
        timings: LongArray,
        amplitudes: IntArray,
        repeat: Int,
        result: MethodChannel.Result
    ) {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val effect = VibrationEffect.createWaveform(timings, amplitudes, repeat)
                vibrator?.vibrate(effect)
                result.success(true)
            } else {
                result.error("NOT_SUPPORTED", "Waveform vibration requires Android O+", null)
            }
        } catch (e: Exception) {
            result.error("VIBRATION_FAILED", e.message, null)
        }
    }
    
    private fun playPredefinedEffect(effectId: Int, result: MethodChannel.Result) {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                val effect = when (effectId) {
                    0 -> VibrationEffect.createPredefined(VibrationEffect.EFFECT_CLICK)
                    1 -> VibrationEffect.createPredefined(VibrationEffect.EFFECT_DOUBLE_CLICK)
                    2 -> VibrationEffect.createPredefined(VibrationEffect.EFFECT_HEAVY_CLICK)
                    3 -> VibrationEffect.createPredefined(VibrationEffect.EFFECT_TICK)
                    else -> VibrationEffect.createPredefined(VibrationEffect.EFFECT_CLICK)
                }
                vibrator?.vibrate(effect)
                result.success(true)
            } else {
                // Fallback for older devices
                vibrate(50, 255, result)
            }
        } catch (e: Exception) {
            result.error("VIBRATION_FAILED", e.message, null)
        }
    }
}
