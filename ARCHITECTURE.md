# The Right Direction - Architecture Documentation

## Overview

**The Right Direction** is a cross-platform accessibility application built with Flutter, designed to assist users with visual and hearing impairments. The app features two primary modes:

- **Deaf Mode**: Real-time speech-to-text transcription with AI enhancement and sign language recognition
- **Blind Mode**: Object detection with LiDAR support, haptic feedback, and audio navigation guidance

## System Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                          Flutter Application                             │
├─────────────────────────────────────────────────────────────────────────┤
│  ┌─────────────────────────────────────────────────────────────────┐    │
│  │                    Presentation Layer                            │    │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐          │    │
│  │  │   App Mode   │  │  Blind Mode  │  │   Deaf Mode  │          │    │
│  │  │     BLoC     │  │     BLoC     │  │     BLoC     │          │    │
│  │  └──────────────┘  └──────────────┘  └──────────────┘          │    │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐          │    │
│  │  │    Pages     │  │    Pages     │  │    Pages     │          │    │
│  │  │   Widgets    │  │   Widgets    │  │   Widgets    │          │    │
│  │  └──────────────┘  └──────────────┘  └──────────────┘          │    │
│  └─────────────────────────────────────────────────────────────────┘    │
│                                                                          │
│  ┌─────────────────────────────────────────────────────────────────┐    │
│  │                      Domain Layer                                │    │
│  │  ┌─────────────────────────────────────────────────────────┐    │    │
│  │  │  Entities: AppMode, NavigationAlert, Transcription,     │    │    │
│  │  │            SignGesture                                   │    │    │
│  │  └─────────────────────────────────────────────────────────┘    │    │
│  │  ┌─────────────────────────────────────────────────────────┐    │    │
│  │  │  Repository Interfaces (Contracts)                       │    │    │
│  │  └─────────────────────────────────────────────────────────┘    │    │
│  │  ┌─────────────────────────────────────────────────────────┐    │    │
│  │  │  Use Cases: DetectObjects, TranscribeSpeech,            │    │    │
│  │  │             RecognizeSignLanguage, Get/SetAppMode        │    │    │
│  │  └─────────────────────────────────────────────────────────┘    │    │
│  └─────────────────────────────────────────────────────────────────┘    │
│                                                                          │
│  ┌─────────────────────────────────────────────────────────────────┐    │
│  │                       Data Layer                                 │    │
│  │  ┌─────────────────────────────────────────────────────────┐    │    │
│  │  │  Repository Implementations                              │    │    │
│  │  │  Local Data Sources (SharedPreferences)                  │    │    │
│  │  └─────────────────────────────────────────────────────────┘    │    │
│  └─────────────────────────────────────────────────────────────────┘    │
│                                                                          │
│  ┌─────────────────────────────────────────────────────────────────┐    │
│  │                     Core Services Layer                          │    │
│  │  ┌────────────┐ ┌────────────┐ ┌────────────┐ ┌────────────┐   │    │
│  │  │  Camera    │ │  Haptic    │ │    TTS     │ │    STT     │   │    │
│  │  │  Service   │ │  Service   │ │  Service   │ │  Service   │   │    │
│  │  └────────────┘ └────────────┘ └────────────┘ └────────────┘   │    │
│  │  ┌────────────┐ ┌────────────┐ ┌────────────┐ ┌────────────┐   │    │
│  │  │    ML      │ │   LiDAR    │ │ Permission │ │   Gemini   │   │    │
│  │  │  Service   │ │  Service   │ │  Service   │ │  Service   │   │    │
│  │  └────────────┘ └────────────┘ └────────────┘ └────────────┘   │    │
│  └─────────────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────────────┘
                                    │
                    ┌───────────────┴───────────────┐
                    │                               │
        ┌───────────▼──────────┐      ┌────────────▼──────────┐
        │   iOS Platform       │      │   Android Platform     │
        │   ─────────────      │      │   ─────────────────    │
        │   • ARKit/LiDAR      │      │   • VibrationEffect    │
        │   • Core Haptics     │      │   • ML Kit             │
        │   • Speech Framework │      │   • Speech Recognizer  │
        │   • AVFoundation     │      │   • CameraX            │
        └──────────────────────┘      └────────────────────────┘
```

## Directory Structure

```
lib/
├── main.dart                      # App entry point, BLoC providers
├── core/
│   ├── di/
│   │   └── injection.dart         # Dependency injection (get_it)
│   ├── services/
│   │   ├── camera_service.dart    # Camera abstraction
│   │   ├── gemini_service.dart    # Gemini AI integration
│   │   ├── haptic_service.dart    # Haptic patterns & feedback
│   │   ├── lidar_service.dart     # iOS LiDAR depth sensing
│   │   ├── ml_service.dart        # TensorFlow Lite inference
│   │   ├── permission_service.dart# Platform permissions
│   │   ├── stt_service.dart       # Speech-to-text
│   │   └── tts_service.dart       # Text-to-speech
│   └── theme/
│       └── app_theme.dart         # High-contrast accessible theme
├── features/
│   ├── app_mode/                  # Mode switching feature
│   │   ├── data/
│   │   ├── domain/
│   │   └── presentation/
│   ├── blind_mode/                # Blind user assistance
│   │   ├── data/
│   │   ├── domain/
│   │   └── presentation/
│   └── deaf_mode/                 # Deaf user assistance
│       ├── data/
│       ├── domain/
│       └── presentation/

ios/Runner/
├── AppDelegate.swift              # Platform channels for haptics/LiDAR
├── Info.plist                     # Permissions & capabilities
└── Runner-Bridging-Header.h       # Swift/Obj-C bridging

android/app/src/main/
├── kotlin/com/therightdirection/
│   └── MainActivity.kt            # Platform channels for vibration
└── AndroidManifest.xml            # Permissions & services
```

## Feature Details

### App Mode Feature

Manages switching between Deaf and Blind modes with haptic confirmation.

| Component | Description |
|-----------|-------------|
| **AppMode Entity** | Enum: `deaf`, `blind` |
| **AppModeRepository** | Persists mode to SharedPreferences |
| **AppModeBloc** | Handles mode toggle, swipe detection |
| **ModeSwitchGestureDetector** | Horizontal swipe with 300 velocity threshold |

**Mode Switch Haptic Patterns:**
- Deaf Mode: 2 short blips (100ms each)
- Blind Mode: 3 short blips (100ms each)

### Blind Mode Feature

Provides real-time object detection and navigation assistance.

| Component | Description |
|-----------|-------------|
| **NavigationAlert** | 5 levels: clear, low, moderate, high, critical |
| **ObjectDetectionRepository** | Combines ML + LiDAR for depth-aware detection |
| **BlindModeBloc** | Coordinates detection, haptics, and TTS |

**Alert Level Distance Thresholds:**
- Critical: < 0.5m (immediate danger)
- High: 0.5-1.0m (obstacle very close)
- Moderate: 1.0-2.0m (obstacle approaching)
- Low: 2.0-4.0m (obstacle detected)
- Clear: > 4.0m (path clear)

**Haptic Patterns by Alert Level:**
| Level | Pattern |
|-------|---------|
| Critical | 3 long pulses, increasing intensity |
| High | Rapid double pulses |
| Moderate | Medium-spaced pulses |
| Low | Slow, soft pulses |
| Clear | No haptic feedback |

### Deaf Mode Feature

Provides speech transcription with AI enhancement and sign language recognition.

| Component | Description |
|-----------|-------------|
| **Transcription** | Contains text, confidence, emotional context |
| **SignGesture** | Recognized ASL sign with meaning |
| **SpeechRecognitionRepository** | STT + Gemini enhancement |
| **SignLanguageRepository** | MediaPipe hand tracking + gesture classification |
| **DeafModeBloc** | Coordinates all input/output streams |

**Transcription Sources:**
- `microphone`: Live speech recognition
- `signLanguage`: Recognized sign gestures
- `external`: TTS output or imported text

**Gemini AI Enhancement:**
- Corrects transcription errors
- Detects speaker intent and emotional context
- Identifies urgency level (low/normal/high/urgent)

## Core Services

### CameraService
```dart
abstract class CameraService {
  Future<void> initialize();
  Future<void> startImageStream(void Function(CameraImage) onImage);
  Future<void> stopImageStream();
  void dispose();
}
```

### HapticService
```dart
abstract class HapticService {
  Future<void> initialize();
  Future<void> playPattern(HapticPattern pattern);
  Future<void> playContinuous(double intensity, double sharpness, Duration duration);
  void stop();
}
```

Defined patterns: `deafModeActivated`, `blindModeActivated`, `objectDetected`, `proximityWarning`, `criticalAlert`, `success`, `error`, `attention`

### TtsService
```dart
abstract class TtsService {
  Future<void> initialize();
  Future<void> speak(String text, {TtsPriority priority});
  Future<void> stop();
  Stream<bool> get isSpeakingStream;
}
```

Priority levels: `low`, `normal`, `high`, `critical`

### SttService
```dart
abstract class SttService {
  Future<void> initialize();
  Future<void> startListening();
  Future<void> stopListening();
  Stream<SttResult> get resultStream;
  Stream<double> get soundLevelStream;
}
```

### MlService
```dart
abstract class MlService {
  Future<void> loadModel(String modelPath);
  Future<List<Detection>> runInference(Uint8List imageBytes, int width, int height);
  Future<List<HandLandmark>> detectHandLandmarks(CameraImage image);
}
```

Models:
- Object Detection: SSD MobileNet v1 (COCO labels)
- Hand Landmarks: MediaPipe Hand Landmarker
- Sign Classification: Custom TFLite model

### LidarService
```dart
abstract class LidarService {
  Future<bool> isAvailable();
  Future<void> initialize();
  Future<void> startScanning();
  Future<void> stopScanning();
  Stream<DepthData> get depthStream;
  Future<double?> getDepthAtPoint(double x, double y);
  Future<ClosestPoint?> getClosestDistance();
}
```

Depth zones:
- Immediate: < 0.5m
- Near: 0.5-1.5m
- Medium: 1.5-3.0m
- Far: > 3.0m

### PermissionService
```dart
abstract class PermissionService {
  Future<PermissionStatus> checkDeafModePermissions();
  Future<PermissionStatus> checkBlindModePermissions();
  Future<Map<Permission, PermissionResult>> requestDeafModePermissions();
  Future<Map<Permission, PermissionResult>> requestBlindModePermissions();
}
```

### GeminiService
```dart
abstract class GeminiService {
  Future<void> initialize(String apiKey);
  Future<EnhancedTranscription> enhanceTranscription(String rawText);
  Future<String> summarizeConversation(List<String> messages);
}
```

## Platform Channels

### iOS Platform Channels

**Haptics Channel** (`com.therightdirection/haptics`):
| Method | Parameters | Description |
|--------|------------|-------------|
| `initializeCoreHaptics` | - | Initialize CHHapticEngine |
| `disposeCoreHaptics` | - | Stop and dispose engine |
| `playPattern` | `pattern: List<Map>` | Play custom haptic pattern |
| `playContinuousHaptic` | `intensity, sharpness, duration` | Play continuous vibration |
| `stopHaptic` | - | Stop current haptic |

**LiDAR Channel** (`com.therightdirection/lidar`):
| Method | Parameters | Description |
|--------|------------|-------------|
| `isLidarAvailable` | - | Check LiDAR hardware support |
| `initializeLidar` | - | Initialize ARSession |
| `startScanning` | - | Begin depth capture |
| `stopScanning` | - | Pause ARSession |
| `getDepthAtPoint` | `x, y` | Get depth at normalized coords |
| `getClosestDistance` | - | Get nearest object distance |

**Depth Stream** (`com.therightdirection/lidar/depth_stream`):
Event channel providing depth data at 10 FPS with 9-point grid sampling.

### Android Platform Channels

**Haptics Channel** (`com.therightdirection/haptics`):
| Method | Parameters | Description |
|--------|------------|-------------|
| `hasVibrator` | - | Check vibrator availability |
| `hasAmplitudeControl` | - | Check amplitude support (API 26+) |
| `vibrate` | `duration, amplitude` | Single vibration |
| `vibratePattern` | `pattern, amplitudes, repeat` | Pattern vibration |
| `playWaveform` | `timings, amplitudes, repeat` | Waveform vibration (API 26+) |
| `playPredefinedEffect` | `effectId` | Predefined effect (API 29+) |
| `cancel` | - | Cancel current vibration |

## Accessibility Considerations

### Visual Accessibility
- High contrast theme with configurable colors
- Large touch targets (minimum 56x56dp)
- Full VoiceOver/TalkBack support
- Semantic labels on all interactive elements
- Clear visual hierarchy

### Haptic Accessibility
- Distinct patterns for different events
- Customizable vibration intensity
- Fallback for devices without advanced haptics
- Throttled feedback to prevent overstimulation

### Audio Accessibility
- Priority-based TTS queue
- Interruptible announcements
- Configurable speech rate and pitch
- Sound level visualization for deaf users

### Gesture Design
- Simple swipe gestures for mode switching
- Large tap areas
- No complex multi-finger gestures
- Gesture alternatives available

## Performance Optimizations

### Throttling
| Feature | Throttle | Reason |
|---------|----------|--------|
| Object Detection | 200ms | Prevent CPU overload |
| Haptic Feedback | 300ms | Avoid overwhelming user |
| TTS Announcements | 2000ms | Allow previous to complete |
| Depth Stream | 100ms (10 FPS) | Balance accuracy & battery |

### Memory Management
- Camera frames processed in-place
- ML models loaded once, cached
- Conversation history capped at 50 items
- Image buffers released immediately after use

### Battery Optimization
- LiDAR only active when Blind Mode enabled
- Speech recognition paused when app backgrounded
- Background audio only for active TTS
- Efficient YUV420 to RGB conversion

## Testing Strategy

### Unit Tests
- Use case logic
- BLoC state transitions
- Entity validation
- Service method contracts

### Widget Tests
- Accessibility labels present
- Touch target sizes
- Theme contrast ratios
- Gesture recognition

### Integration Tests
- Mode switching flow
- Permission request handling
- Camera/microphone initialization
- Platform channel communication

### Accessibility Testing
- VoiceOver walkthrough (iOS)
- TalkBack walkthrough (Android)
- Switch control navigation
- Screen reader compatibility

## Security & Privacy

### Data Handling
- All ML inference runs on-device
- No camera/audio data stored or transmitted
- Gemini API calls use HTTPS only
- API keys stored in environment variables

### Permission Philosophy
- Request permissions just-in-time
- Explain purpose before requesting
- Graceful degradation without permissions
- Easy access to settings for permission changes

## Future Considerations

1. **Multi-language support** for speech recognition and sign language
2. **Wearable integration** (Apple Watch haptics, WearOS)
3. **Offline Gemini** using on-device LLM
4. **Custom sign language models** for regional variations
5. **Social features** for sharing transcriptions
6. **AR overlay** for blind mode object labels
