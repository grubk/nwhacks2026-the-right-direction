import 'dart:async';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_recognition_error.dart';

/// Speech-to-Text service abstraction
/// Provides real-time transcription for deaf users
abstract class SttService {
  /// Initialize STT engine
  Future<bool> initialize();
  
  /// Start listening for speech
  Future<void> startListening({
    String localeId = 'en_US',
    bool partialResults = true,
  });
  
  /// Stop listening
  Future<void> stopListening();
  
  /// Cancel listening
  Future<void> cancelListening();
  
  /// Check if currently listening
  bool get isListening;
  
  /// Check if STT is available
  bool get isAvailable;
  
  /// Stream of transcription results
  Stream<TranscriptionResult> get transcriptionStream;
  
  /// Stream of listening state changes
  Stream<SttState> get stateStream;
  
  /// Stream of sound level changes (for visual feedback)
  Stream<double> get soundLevelStream;
  
  /// Get available locales
  Future<List<SttLocale>> getLocales();
  
  /// Dispose STT engine
  Future<void> dispose();
}

class TranscriptionResult {
  final String text;
  final bool isFinal;
  final double confidence;
  final DateTime timestamp;
  final List<TranscriptionAlternative> alternatives;

  const TranscriptionResult({
    required this.text,
    required this.isFinal,
    required this.confidence,
    required this.timestamp,
    this.alternatives = const [],
  });

  TranscriptionResult copyWith({
    String? text,
    bool? isFinal,
    double? confidence,
    DateTime? timestamp,
    List<TranscriptionAlternative>? alternatives,
  }) {
    return TranscriptionResult(
      text: text ?? this.text,
      isFinal: isFinal ?? this.isFinal,
      confidence: confidence ?? this.confidence,
      timestamp: timestamp ?? this.timestamp,
      alternatives: alternatives ?? this.alternatives,
    );
  }
}

class TranscriptionAlternative {
  final String text;
  final double confidence;

  const TranscriptionAlternative({
    required this.text,
    required this.confidence,
  });
}

class SttLocale {
  final String localeId;
  final String name;

  const SttLocale({
    required this.localeId,
    required this.name,
  });
}

enum SttState {
  idle,
  initializing,
  listening,
  processing,
  error,
  notAvailable,
}

class SttServiceImpl implements SttService {
  final SpeechToText _speech = SpeechToText();
  final _transcriptionController = StreamController<TranscriptionResult>.broadcast();
  final _stateController = StreamController<SttState>.broadcast();
  final _soundLevelController = StreamController<double>.broadcast();
  
  bool _isInitialized = false;
  bool _isListening = false;
  bool _isAvailable = false;

  @override
  bool get isListening => _isListening;

  @override
  bool get isAvailable => _isAvailable;

  @override
  Stream<TranscriptionResult> get transcriptionStream => _transcriptionController.stream;

  @override
  Stream<SttState> get stateStream => _stateController.stream;

  @override
  Stream<double> get soundLevelStream => _soundLevelController.stream;

  @override
  Future<bool> initialize() async {
    if (_isInitialized) return _isAvailable;

    _stateController.add(SttState.initializing);

    try {
      _isAvailable = await _speech.initialize(
        onError: _handleError,
        onStatus: _handleStatus,
        debugLogging: false,
      );

      _isInitialized = true;
      
      if (_isAvailable) {
        _stateController.add(SttState.idle);
      } else {
        _stateController.add(SttState.notAvailable);
      }

      return _isAvailable;
    } catch (e) {
      _stateController.add(SttState.error);
      return false;
    }
  }

  void _handleError(SpeechRecognitionError error) {
    _isListening = false;
    _stateController.add(SttState.error);
  }

  void _handleStatus(String status) {
    switch (status) {
      case 'listening':
        _isListening = true;
        _stateController.add(SttState.listening);
        break;
      case 'notListening':
        _isListening = false;
        _stateController.add(SttState.idle);
        break;
      case 'done':
        _isListening = false;
        _stateController.add(SttState.idle);
        break;
    }
  }

  @override
  Future<void> startListening({
    String localeId = 'en_US',
    bool partialResults = true,
  }) async {
    if (!_isAvailable || _isListening) return;

    await _speech.listen(
      onResult: _handleResult,
      localeId: localeId,
      partialResults: partialResults,
      listenMode: ListenMode.dictation,
      onSoundLevelChange: (level) {
        _soundLevelController.add(level);
      },
    );

    _isListening = true;
    _stateController.add(SttState.listening);
  }

  void _handleResult(SpeechRecognitionResult result) {
    final transcription = TranscriptionResult(
      text: result.recognizedWords,
      isFinal: result.finalResult,
      confidence: result.confidence,
      timestamp: DateTime.now(),
      alternatives: result.alternates.map((alt) => TranscriptionAlternative(
        text: alt.recognizedWords,
        confidence: alt.confidence,
      )).toList(),
    );

    _transcriptionController.add(transcription);
  }

  @override
  Future<void> stopListening() async {
    if (!_isListening) return;
    
    await _speech.stop();
    _isListening = false;
    _stateController.add(SttState.idle);
  }

  @override
  Future<void> cancelListening() async {
    if (!_isListening) return;
    
    await _speech.cancel();
    _isListening = false;
    _stateController.add(SttState.idle);
  }

  @override
  Future<List<SttLocale>> getLocales() async {
    if (!_isAvailable) return [];

    final locales = await _speech.locales();
    return locales.map((locale) => SttLocale(
      localeId: locale.localeId,
      name: locale.name,
    )).toList();
  }

  @override
  Future<void> dispose() async {
    await stopListening();
    await _transcriptionController.close();
    await _stateController.close();
    await _soundLevelController.close();
  }
}
