import '../entities/transcription.dart';
import '../repositories/speech_recognition_repository.dart';

/// Use case for transcribing speech to text
class TranscribeSpeech {
  final SpeechRecognitionRepository repository;

  TranscribeSpeech(this.repository);

  Future<void> start({String locale = 'en_US'}) async {
    await repository.startListening(locale: locale);
  }

  Future<void> stop() async {
    await repository.stopListening();
  }

  bool get isListening => repository.isListening;

  Stream<Transcription> get transcriptionStream => repository.transcriptionStream;

  Stream<double> get soundLevelStream => repository.soundLevelStream;

  List<Transcription> get history => repository.history;

  void clearHistory() => repository.clearHistory();

  Future<void> setEnhancementEnabled(bool enabled) async {
    await repository.setEnhancementEnabled(enabled);
  }
}
