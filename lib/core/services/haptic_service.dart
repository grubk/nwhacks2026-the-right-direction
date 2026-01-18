import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:vibration/vibration.dart';

/// Haptic feedback patterns for accessibility
enum HapticPattern {
  /// Single light tap - general acknowledgment
  light,
  
  /// Single medium tap - action confirmed
  medium,
  
  /// Single heavy tap - important notification
  heavy,
  
  /// 2 blips - Deaf Mode activated
  deafModeActivated,
  
  /// 3 blips - Blind Mode activated
  blindModeActivated,
  
  /// Rapid pulses - object very close (< 0.5m)
  proximityVeryClose,
  
  /// Medium pulses - object close (0.5-1m)
  proximityClose,
  
  /// Slow pulses - object at medium distance (1-2m)
  proximityMedium,
  
  /// Single light pulse - object far (2-4m)
  proximityFar,
  
  /// Success pattern - action completed
  success,
  
  /// Error pattern - action failed
  error,
  
  /// Warning pattern - attention needed
  warning,
  
  /// Direction left - object on left
  directionLeft,
  
  /// Direction right - object on right
  directionRight,
  
  /// Direction center - object ahead
  directionCenter,
}

/// Abstract haptic service interface
/// Platform-specific implementations handle iOS Core Haptics and Android VibrationEffect
abstract class HapticService {
  /// Initialize haptic engine
  Future<void> initialize();
  
  /// Check if device supports haptic feedback
  Future<bool> hasHapticSupport();
  
  /// Check if device supports custom vibration patterns
  Future<bool> hasCustomVibrationSupport();
  
  /// Play a predefined haptic pattern
  Future<void> playPattern(HapticPattern pattern);
  
  /// Play custom vibration pattern (duration in ms, pause in ms)
  Future<void> playCustomPattern(List<int> pattern, {List<int>? amplitudes});
  
  /// Play single vibration with duration
  Future<void> vibrate({int duration = 100, int amplitude = 128});
  
  /// Stop any ongoing vibration
  Future<void> cancel();
  
  /// Dispose haptic engine
  Future<void> dispose();
}

class HapticServiceImpl implements HapticService {
  static const _channel = MethodChannel('com.therightdirection/haptics');
  bool _hasHaptics = false;
  bool _hasCustomVibration = false;
  bool _initialized = false;

  @override
  Future<void> initialize() async {
    if (_initialized) return;
    
    _hasHaptics = await Vibration.hasVibrator() ?? false;
    _hasCustomVibration = await Vibration.hasCustomVibrationsSupport() ?? false;
    
    // Initialize platform-specific haptic engine
    if (Platform.isIOS) {
      try {
        await _channel.invokeMethod('initializeCoreHaptics');
      } catch (e) {
        // Core Haptics not available, fall back to standard vibration
      }
    }
    
    _initialized = true;
  }

  @override
  Future<bool> hasHapticSupport() async {
    return _hasHaptics;
  }

  @override
  Future<bool> hasCustomVibrationSupport() async {
    return _hasCustomVibration;
  }

  @override
  Future<void> playPattern(HapticPattern pattern) async {
    if (!_hasHaptics) return;

    switch (pattern) {
      case HapticPattern.light:
        await HapticFeedback.lightImpact();
        break;
        
      case HapticPattern.medium:
        await HapticFeedback.mediumImpact();
        break;
        
      case HapticPattern.heavy:
        await HapticFeedback.heavyImpact();
        break;
        
      case HapticPattern.deafModeActivated:
        // 2 blips for Deaf Mode
        await _playBlips(2, duration: 100, pause: 150);
        break;
        
      case HapticPattern.blindModeActivated:
        // 3 blips for Blind Mode
        await _playBlips(3, duration: 100, pause: 150);
        break;
        
      case HapticPattern.proximityVeryClose:
        // Rapid continuous pulses - very urgent
        await playCustomPattern(
          [0, 50, 30, 50, 30, 50, 30, 50, 30],
          amplitudes: [0, 255, 0, 255, 0, 255, 0, 255, 0],
        );
        break;
        
      case HapticPattern.proximityClose:
        // Fast pulses
        await playCustomPattern(
          [0, 80, 50, 80, 50, 80],
          amplitudes: [0, 200, 0, 200, 0, 200],
        );
        break;
        
      case HapticPattern.proximityMedium:
        // Medium pulses
        await playCustomPattern(
          [0, 100, 100, 100],
          amplitudes: [0, 150, 0, 150],
        );
        break;
        
      case HapticPattern.proximityFar:
        // Single light pulse
        await vibrate(duration: 50, amplitude: 100);
        break;
        
      case HapticPattern.success:
        await playCustomPattern(
          [0, 50, 50, 100],
          amplitudes: [0, 128, 0, 255],
        );
        break;
        
      case HapticPattern.error:
        await playCustomPattern(
          [0, 200, 100, 200],
          amplitudes: [0, 255, 0, 255],
        );
        break;
        
      case HapticPattern.warning:
        await playCustomPattern(
          [0, 100, 50, 100, 50, 100],
          amplitudes: [0, 200, 0, 200, 0, 200],
        );
        break;
        
      case HapticPattern.directionLeft:
        // Two quick pulses on the "left" - conceptually
        await playCustomPattern(
          [0, 80, 30, 40],
          amplitudes: [0, 200, 0, 100],
        );
        break;
        
      case HapticPattern.directionRight:
        // Inverse pattern for "right"
        await playCustomPattern(
          [0, 40, 30, 80],
          amplitudes: [0, 100, 0, 200],
        );
        break;
        
      case HapticPattern.directionCenter:
        // Single centered pulse
        await vibrate(duration: 100, amplitude: 180);
        break;
    }
  }

  Future<void> _playBlips(int count, {int duration = 100, int pause = 150}) async {
    final pattern = <int>[0]; // Start with 0 delay
    final amplitudes = <int>[0];
    
    for (int i = 0; i < count; i++) {
      pattern.add(duration);
      amplitudes.add(200);
      if (i < count - 1) {
        pattern.add(pause);
        amplitudes.add(0);
      }
    }
    
    await playCustomPattern(pattern, amplitudes: amplitudes);
  }

  @override
  Future<void> playCustomPattern(List<int> pattern, {List<int>? amplitudes}) async {
    if (!_hasHaptics) return;
    
    if (_hasCustomVibration && amplitudes != null) {
      await Vibration.vibrate(pattern: pattern, intensities: amplitudes);
    } else {
      // Fallback for devices without custom vibration support
      await Vibration.vibrate(pattern: pattern);
    }
  }

  @override
  Future<void> vibrate({int duration = 100, int amplitude = 128}) async {
    if (!_hasHaptics) return;
    
    if (_hasCustomVibration) {
      await Vibration.vibrate(duration: duration, amplitude: amplitude);
    } else {
      await Vibration.vibrate(duration: duration);
    }
  }

  @override
  Future<void> cancel() async {
    await Vibration.cancel();
  }

  @override
  Future<void> dispose() async {
    await cancel();
    if (Platform.isIOS) {
      try {
        await _channel.invokeMethod('disposeCoreHaptics');
      } catch (e) {
        // Ignore errors during disposal
      }
    }
  }
}
