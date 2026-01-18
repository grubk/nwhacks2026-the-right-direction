import 'dart:async';

import '../../../../core/services/stt_service.dart';
import '../../../../core/services/gemini_service.dart' as gemini_service;
import '../../domain/entities/transcription.dart';
import '../../domain/repositories/speech_recognition_repository.dart';

class SpeechRecognitionRepositoryImpl implements SpeechRecognitionRepository {
  final SttService sttService;
  final gemini_service.GeminiService geminiService;

  final _transcriptionController = StreamController<Transcription>.broadcast();
  final _history = <Transcription>[];
  
  StreamSubscription? _sttSubscription;
  bool _enhancementEnabled = true;
  bool _isListening = false;

  SpeechRecognitionRepositoryImpl({
    required this.sttService,
    required this.geminiService,
  });

  @override
  bool get isListening => _isListening;

  @override
  Stream<Transcription> get transcriptionStream => _transcriptionController.stream;

  @override
  Stream<double> get soundLevelStream => sttService.soundLevelStream;

  @override
  List<Transcription> get history => List.unmodifiable(_history);

  @override
  Future<void> startListening({String locale = 'en_US'}) async {
    if (_isListening) return;

    // Initialize services
    final available = await sttService.initialize();
    if (!available) {
      throw Exception('Speech recognition not available');
    }

    // Subscribe to transcription results
    _sttSubscription = sttService.transcriptionStream.listen(_handleTranscription);

    // Start listening
    await sttService.startListening(localeId: locale, partialResults: true);
    _isListening = true;
  }

  Future<void> _handleTranscription(TranscriptionResult result) async {
    // Create base transcription
    var transcription = Transcription(
      text: result.text,
      confidence: result.confidence,
      isFinal: result.isFinal,
      timestamp: result.timestamp,
      source: TranscriptionSource.speech,
    );

    // Enhance with Gemini if enabled and final
    if (_enhancementEnabled && result.isFinal && geminiService.isAvailable) {
      try {
        // Get context from recent history
        final context = _history.length >= 2
            ? _history.sublist(_history.length - 2).map((t) => t.text).join(' ')
            : null;

        final enhanced = await geminiService.enhanceTranscription(
          result.text,
          context: context,
        );

        transcription = transcription.copyWith(
          enhancedText: enhanced.enhanced,
          emotionalContext: enhanced.emotionalTone != null
              ? EmotionalContext(
                  tone: _mapEmotionalTone(enhanced.emotionalTone!),
                  intensity: enhanced.confidenceImprovement,
                  isUrgent: enhanced.emotionalTone == gemini_service.EmotionalTone.urgent,
                )
              : null,
        );
      } catch (e) {
        // Enhancement failed, use original transcription
      }
    }

    // Add to history if final
    if (transcription.isFinal && transcription.text.isNotEmpty) {
      _history.add(transcription);
      
      // Keep history manageable
      if (_history.length > 100) {
        _history.removeAt(0);
      }
    }

    _transcriptionController.add(transcription);
  }

  EmotionalTone _mapEmotionalTone(gemini_service.EmotionalTone tone) {
    switch (tone) {
      case gemini_service.EmotionalTone.happy:
        return EmotionalTone.happy;
      case gemini_service.EmotionalTone.sad:
        return EmotionalTone.sad;
      case gemini_service.EmotionalTone.angry:
        return EmotionalTone.angry;
      case gemini_service.EmotionalTone.anxious:
        return EmotionalTone.anxious;
      case gemini_service.EmotionalTone.confused:
        return EmotionalTone.confused;
      case gemini_service.EmotionalTone.urgent:
        return EmotionalTone.urgent;
      case gemini_service.EmotionalTone.neutral:
        return EmotionalTone.neutral;
    }
  }

  @override
  Future<void> stopListening() async {
    if (!_isListening) return;

    await sttService.stopListening();
    await _sttSubscription?.cancel();
    _isListening = false;
  }

  @override
  void clearHistory() {
    _history.clear();
  }

  @override
  Future<void> setEnhancementEnabled(bool enabled) async {
    _enhancementEnabled = enabled;
  }

  @override
  Future<void> dispose() async {
    await stopListening();
    await _transcriptionController.close();
  }
}
