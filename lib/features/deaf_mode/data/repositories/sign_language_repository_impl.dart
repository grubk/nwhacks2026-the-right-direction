import 'dart:async';

import 'package:camera/camera.dart' hide CameraImage;
import '../../../../core/services/camera_service.dart';
import '../../../../core/services/ml_service.dart' hide SignLanguageType;
import '../../domain/entities/sign_gesture.dart';
import '../../domain/repositories/sign_language_repository.dart';

class SignLanguageRepositoryImpl implements SignLanguageRepository {
  final CameraService cameraService;
  final MlService mlService;

  final _gestureController = StreamController<SignGesture>.broadcast();
  
  StreamSubscription? _frameSubscription;
  SignLanguageType _languageType = SignLanguageType.asl;
  bool _isRecognizing = false;
  
  // Throttle recognition to manage performance
  DateTime? _lastRecognitionTime;
  static const _recognitionInterval = Duration(milliseconds: 100);
  
  // Gesture stability tracking
  String? _lastGesture;
  int _gestureStabilityCount = 0;
  static const _stabilityThreshold = 3; // Must see same gesture 3 times

  SignLanguageRepositoryImpl({
    required this.cameraService,
    required this.mlService,
  });

  @override
  bool get isRecognizing => _isRecognizing;

  @override
  Stream<SignGesture> get gestureStream => _gestureController.stream;

  @override
  SignLanguageType get languageType => _languageType;

  @override
  Future<void> startRecognition() async {
    if (_isRecognizing) return;

    // Initialize services
    await mlService.initialize();
    await cameraService.initialize(direction: CameraLensDirection.front);

    // Start camera streaming
    final cameraImpl = cameraService as CameraServiceImpl;
    await cameraImpl.startImageStream();

    // Subscribe to camera frames
    _frameSubscription = cameraService.frameStream.listen(_processFrame);

    _isRecognizing = true;
  }

  Future<void> _processFrame(CameraImage frame) async {
    // Throttle recognition
    final now = DateTime.now();
    if (_lastRecognitionTime != null &&
        now.difference(_lastRecognitionTime!) < _recognitionInterval) {
      return;
    }
    _lastRecognitionTime = now;

    try {
      // Detect hand landmarks
      final landmarks = await mlService.detectHandLandmarks(frame);
      if (landmarks == null) {
        _resetStability();
        return;
      }

      // Recognize sign gesture
      final result = await mlService.recognizeSign(landmarks);
      if (result == null) {
        _resetStability();
        return;
      }

      // Apply stability filter
      if (result.gesture == _lastGesture) {
        _gestureStabilityCount++;
      } else {
        _lastGesture = result.gesture;
        _gestureStabilityCount = 1;
      }

      // Only emit if gesture is stable
      if (_gestureStabilityCount >= _stabilityThreshold) {
        final gesture = SignGesture(
          gesture: result.gesture,
          meaning: result.meaning,
          confidence: result.confidence,
          timestamp: DateTime.now(),
          language: _languageType,
        );

        _gestureController.add(gesture);
        
        // Reset after emitting to allow new gestures
        _gestureStabilityCount = 0;
      }
    } catch (e) {
      // Silently handle recognition errors
    }
  }

  void _resetStability() {
    _lastGesture = null;
    _gestureStabilityCount = 0;
  }

  @override
  Future<void> stopRecognition() async {
    _isRecognizing = false;
    
    await _frameSubscription?.cancel();
    await cameraService.pause();
    
    _resetStability();
  }

  @override
  Future<void> setLanguageType(SignLanguageType type) async {
    _languageType = type;
    // Could reload models here if needed for different languages
  }

  @override
  Future<void> dispose() async {
    await stopRecognition();
    await _gestureController.close();
  }
}
