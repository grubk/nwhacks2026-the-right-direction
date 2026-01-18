import '../entities/sign_gesture.dart';
import '../repositories/sign_language_repository.dart';

/// Use case for recognizing sign language
class RecognizeSignLanguage {
  final SignLanguageRepository repository;

  RecognizeSignLanguage(this.repository);

  Future<void> start() async {
    await repository.startRecognition();
  }

  Future<void> stop() async {
    await repository.stopRecognition();
  }

  bool get isRecognizing => repository.isRecognizing;

  Stream<SignGesture> get gestureStream => repository.gestureStream;

  SignLanguageType get languageType => repository.languageType;

  Future<void> setLanguageType(SignLanguageType type) async {
    await repository.setLanguageType(type);
  }
}
