import '../entities/transcription.dart';

/// Repository interface for speech recognition operations
abstract class SpeechRecognitionRepository {
  /// Start speech recognition
  Future<void> startListening({String locale = 'en_US'});
  
  /// Stop speech recognition
  Future<void> stopListening();
  
  /// Check if currently listening
  bool get isListening;
  
  /// Stream of transcriptions
  Stream<Transcription> get transcriptionStream;
  
  /// Stream of sound levels (for visual feedback)
  Stream<double> get soundLevelStream;
  
  /// Get transcription history
  List<Transcription> get history;
  
  /// Clear transcription history
  void clearHistory();
  
  /// Enable/disable AI enhancement
  Future<void> setEnhancementEnabled(bool enabled);
  
  /// Dispose resources
  Future<void> dispose();
}
