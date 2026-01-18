import '../entities/sign_gesture.dart';

/// Repository interface for sign language recognition
abstract class SignLanguageRepository {
  /// Start sign language recognition
  Future<void> startRecognition();
  
  /// Stop sign language recognition
  Future<void> stopRecognition();
  
  /// Check if currently recognizing
  bool get isRecognizing;
  
  /// Stream of recognized gestures
  Stream<SignGesture> get gestureStream;
  
  /// Set sign language type
  Future<void> setLanguageType(SignLanguageType type);
  
  /// Get current language type
  SignLanguageType get languageType;
  
  /// Dispose resources
  Future<void> dispose();
}
