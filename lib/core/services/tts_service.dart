import 'dart:async';
import 'dart:io';
import 'package:flutter_tts/flutter_tts.dart';

/// Text-to-Speech service abstraction
/// Provides spoken feedback for blind users
abstract class TtsService {
  /// Initialize TTS engine
  Future<void> initialize();
  
  /// Speak the given text
  Future<void> speak(String text, {TtsPriority priority = TtsPriority.normal});
  
  /// Stop current speech
  Future<void> stop();
  
  /// Pause current speech
  Future<void> pause();
  
  /// Check if TTS is currently speaking
  bool get isSpeaking;
  
  /// Set speech rate (0.0 to 1.0)
  Future<void> setSpeechRate(double rate);
  
  /// Set pitch (0.5 to 2.0)
  Future<void> setPitch(double pitch);
  
  /// Set volume (0.0 to 1.0)
  Future<void> setVolume(double volume);
  
  /// Set language
  Future<void> setLanguage(String languageCode);
  
  /// Get available languages
  Future<List<String>> getLanguages();
  
  /// Queue text for speaking
  Future<void> queueSpeak(String text);
  
  /// Clear speech queue
  Future<void> clearQueue();
  
  /// Stream of TTS state changes
  Stream<TtsState> get stateStream;
  
  /// Dispose TTS engine
  Future<void> dispose();
}

enum TtsState {
  playing,
  stopped,
  paused,
  continued,
}

enum TtsPriority {
  /// Can be interrupted by new speech
  low,
  
  /// Normal priority
  normal,
  
  /// High priority, interrupts current speech
  high,
  
  /// Critical priority, always speaks immediately
  critical,
}

class TtsServiceImpl implements TtsService {
  final FlutterTts _tts = FlutterTts();
  final _stateController = StreamController<TtsState>.broadcast();
  final _speechQueue = <_QueuedSpeech>[];
  bool _isSpeaking = false;
  bool _isProcessingQueue = false;
  TtsPriority _currentPriority = TtsPriority.low;

  @override
  bool get isSpeaking => _isSpeaking;

  @override
  Stream<TtsState> get stateStream => _stateController.stream;

  @override
  Future<void> initialize() async {
    // Configure TTS for accessibility
    if (Platform.isIOS) {
      await _tts.setSharedInstance(true);
      await _tts.setIosAudioCategory(
        IosTextToSpeechAudioCategory.ambient,
        [
          IosTextToSpeechAudioCategoryOptions.allowBluetooth,
          IosTextToSpeechAudioCategoryOptions.allowBluetoothA2DP,
          IosTextToSpeechAudioCategoryOptions.mixWithOthers,
        ],
        IosTextToSpeechAudioMode.voicePrompt,
      );
    }

    // Set default parameters for accessibility
    await setSpeechRate(0.5); // Slightly slower for clarity
    await setPitch(1.0);
    await setVolume(1.0);
    await setLanguage('en-US');

    // Set up listeners
    _tts.setStartHandler(() {
      _isSpeaking = true;
      _stateController.add(TtsState.playing);
    });

    _tts.setCompletionHandler(() {
      _isSpeaking = false;
      _stateController.add(TtsState.stopped);
      _processQueue();
    });

    _tts.setCancelHandler(() {
      _isSpeaking = false;
      _stateController.add(TtsState.stopped);
    });

    _tts.setPauseHandler(() {
      _stateController.add(TtsState.paused);
    });

    _tts.setContinueHandler(() {
      _stateController.add(TtsState.continued);
    });

    _tts.setErrorHandler((message) {
      _isSpeaking = false;
      _stateController.add(TtsState.stopped);
    });
  }

  @override
  Future<void> speak(String text, {TtsPriority priority = TtsPriority.normal}) async {
    if (text.isEmpty) return;

    // Handle priority
    if (priority == TtsPriority.critical || 
        (priority == TtsPriority.high && _currentPriority.index < priority.index)) {
      await stop();
      _speechQueue.clear();
    }

    _currentPriority = priority;
    await _tts.speak(text);
  }

  @override
  Future<void> queueSpeak(String text) async {
    if (text.isEmpty) return;
    
    _speechQueue.add(_QueuedSpeech(text: text, priority: TtsPriority.normal));
    
    if (!_isSpeaking && !_isProcessingQueue) {
      await _processQueue();
    }
  }

  Future<void> _processQueue() async {
    if (_speechQueue.isEmpty || _isProcessingQueue) return;
    
    _isProcessingQueue = true;
    
    while (_speechQueue.isNotEmpty) {
      final next = _speechQueue.removeAt(0);
      await speak(next.text, priority: next.priority);
      
      // Wait for speech to complete
      await Future.doWhile(() async {
        await Future.delayed(const Duration(milliseconds: 100));
        return _isSpeaking;
      });
    }
    
    _isProcessingQueue = false;
  }

  @override
  Future<void> clearQueue() async {
    _speechQueue.clear();
  }

  @override
  Future<void> stop() async {
    await _tts.stop();
    _isSpeaking = false;
  }

  @override
  Future<void> pause() async {
    await _tts.pause();
  }

  @override
  Future<void> setSpeechRate(double rate) async {
    await _tts.setSpeechRate(rate.clamp(0.0, 1.0));
  }

  @override
  Future<void> setPitch(double pitch) async {
    await _tts.setPitch(pitch.clamp(0.5, 2.0));
  }

  @override
  Future<void> setVolume(double volume) async {
    await _tts.setVolume(volume.clamp(0.0, 1.0));
  }

  @override
  Future<void> setLanguage(String languageCode) async {
    await _tts.setLanguage(languageCode);
  }

  @override
  Future<List<String>> getLanguages() async {
    final languages = await _tts.getLanguages;
    return List<String>.from(languages);
  }

  @override
  Future<void> dispose() async {
    await stop();
    await _stateController.close();
  }
}

class _QueuedSpeech {
  final String text;
  final TtsPriority priority;

  _QueuedSpeech({required this.text, required this.priority});
}
