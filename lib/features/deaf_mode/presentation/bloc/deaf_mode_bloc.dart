import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/services/permission_service.dart';
import '../../../../core/services/tts_service.dart';
import '../../domain/entities/transcription.dart';
import '../../domain/entities/sign_gesture.dart';
import '../../domain/usecases/transcribe_speech.dart';
import '../../domain/usecases/recognize_sign_language.dart';

part 'deaf_mode_event.dart';
part 'deaf_mode_state.dart';

class DeafModeBloc extends Bloc<DeafModeEvent, DeafModeState> {
  final TranscribeSpeech transcribeSpeech;
  final RecognizeSignLanguage recognizeSignLanguage;
  final PermissionService permissionService;
  final TtsService ttsService;

  StreamSubscription? _transcriptionSubscription;
  StreamSubscription? _gestureSubscription;
  StreamSubscription? _soundLevelSubscription;

  DeafModeBloc({
    required this.transcribeSpeech,
    required this.recognizeSignLanguage,
    required this.permissionService,
    required this.ttsService,
  }) : super(const DeafModeState()) {
    on<DeafModeStarted>(_onStarted);
    on<DeafModeStopped>(_onStopped);
    on<DeafModeTranscriptionReceived>(_onTranscriptionReceived);
    on<DeafModeGestureRecognized>(_onGestureRecognized);
    on<DeafModeSoundLevelChanged>(_onSoundLevelChanged);
    on<DeafModeFeatureToggled>(_onFeatureToggled);
    on<DeafModePermissionRequested>(_onPermissionRequested);
    on<DeafModeHistoryCleared>(_onHistoryCleared);
    on<DeafModeSpeakText>(_onSpeakText);
  }

  Future<void> _onStarted(
    DeafModeStarted event,
    Emitter<DeafModeState> emit,
  ) async {
    emit(state.copyWith(status: DeafModeStatus.initializing));

    try {
      // Check permissions
      final permissionStatus = await permissionService.checkDeafModePermissions();
      
      if (!permissionStatus.allGranted) {
        emit(state.copyWith(
          status: DeafModeStatus.permissionRequired,
          missingPermissions: permissionStatus.missingPermissions,
        ));
        return;
      }

      // Initialize TTS for sign language to speech
      await ttsService.initialize();

      // Start speech-to-text if enabled
      if (state.speechToTextEnabled) {
        await _startSpeechRecognition();
      }

      // Start sign language recognition if enabled
      if (state.signRecognitionEnabled) {
        await _startSignRecognition();
      }

      emit(state.copyWith(
        status: DeafModeStatus.active,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: DeafModeStatus.error,
        errorMessage: 'Failed to start Deaf Mode: $e',
      ));
    }
  }

  Future<void> _startSpeechRecognition() async {
    await transcribeSpeech.start();
    
    _transcriptionSubscription = transcribeSpeech.transcriptionStream.listen((t) {
      add(DeafModeTranscriptionReceived(t));
    });
    
    _soundLevelSubscription = transcribeSpeech.soundLevelStream.listen((level) {
      add(DeafModeSoundLevelChanged(level));
    });
  }

  Future<void> _startSignRecognition() async {
    await recognizeSignLanguage.start();
    
    _gestureSubscription = recognizeSignLanguage.gestureStream.listen((g) {
      add(DeafModeGestureRecognized(g));
    });
  }

  Future<void> _onStopped(
    DeafModeStopped event,
    Emitter<DeafModeState> emit,
  ) async {
    await _transcriptionSubscription?.cancel();
    await _gestureSubscription?.cancel();
    await _soundLevelSubscription?.cancel();
    
    await transcribeSpeech.stop();
    await recognizeSignLanguage.stop();
    await ttsService.stop();

    emit(state.copyWith(
      status: DeafModeStatus.inactive,
      currentTranscription: null,
      currentGesture: null,
      soundLevel: 0,
    ));
  }

  Future<void> _onTranscriptionReceived(
    DeafModeTranscriptionReceived event,
    Emitter<DeafModeState> emit,
  ) async {
    final transcription = event.transcription;
    
    // Update conversation history if final
    List<Transcription> newHistory = List.from(state.conversationHistory);
    if (transcription.isFinal && transcription.text.isNotEmpty) {
      newHistory.add(transcription);
      
      // Keep history manageable
      if (newHistory.length > 50) {
        newHistory = newHistory.sublist(newHistory.length - 50);
      }
    }

    emit(state.copyWith(
      currentTranscription: transcription,
      conversationHistory: newHistory,
    ));
  }

  Future<void> _onGestureRecognized(
    DeafModeGestureRecognized event,
    Emitter<DeafModeState> emit,
  ) async {
    final gesture = event.gesture;
    
    emit(state.copyWith(currentGesture: gesture));

    // Speak the recognized sign if TTS is enabled
    if (state.signToSpeechEnabled) {
      await ttsService.speak(gesture.meaning, priority: TtsPriority.high);
    }

    // Add to history as a transcription
    final transcription = Transcription(
      text: gesture.meaning,
      confidence: gesture.confidence,
      isFinal: true,
      timestamp: gesture.timestamp,
      source: TranscriptionSource.signLanguage,
    );

    List<Transcription> newHistory = List.from(state.conversationHistory);
    newHistory.add(transcription);
    
    if (newHistory.length > 50) {
      newHistory = newHistory.sublist(newHistory.length - 50);
    }

    emit(state.copyWith(conversationHistory: newHistory));
  }

  void _onSoundLevelChanged(
    DeafModeSoundLevelChanged event,
    Emitter<DeafModeState> emit,
  ) {
    emit(state.copyWith(soundLevel: event.level));
  }

  Future<void> _onFeatureToggled(
    DeafModeFeatureToggled event,
    Emitter<DeafModeState> emit,
  ) async {
    switch (event.feature) {
      case DeafModeFeature.speechToText:
        final newState = !state.speechToTextEnabled;
        emit(state.copyWith(speechToTextEnabled: newState));
        
        if (newState) {
          await _startSpeechRecognition();
        } else {
          await transcribeSpeech.stop();
          await _transcriptionSubscription?.cancel();
          await _soundLevelSubscription?.cancel();
        }
        break;
        
      case DeafModeFeature.signRecognition:
        final newState = !state.signRecognitionEnabled;
        emit(state.copyWith(signRecognitionEnabled: newState));
        
        if (newState) {
          await _startSignRecognition();
        } else {
          await recognizeSignLanguage.stop();
          await _gestureSubscription?.cancel();
        }
        break;
        
      case DeafModeFeature.signToSpeech:
        emit(state.copyWith(signToSpeechEnabled: !state.signToSpeechEnabled));
        break;
        
      case DeafModeFeature.aiEnhancement:
        final newState = !state.aiEnhancementEnabled;
        emit(state.copyWith(aiEnhancementEnabled: newState));
        await transcribeSpeech.setEnhancementEnabled(newState);
        break;
    }
  }

  Future<void> _onPermissionRequested(
    DeafModePermissionRequested event,
    Emitter<DeafModeState> emit,
  ) async {
    final results = await permissionService.requestDeafModePermissions();
    
    final allGranted = results.values.every(
      (r) => r == PermissionResult.granted,
    );
    
    if (allGranted) {
      add(const DeafModeStarted());
    } else {
      final hasPermanentlyDenied = results.values.any(
        (r) => r == PermissionResult.permanentlyDenied,
      );
      
      if (hasPermanentlyDenied) {
        emit(state.copyWith(
          status: DeafModeStatus.error,
          errorMessage: 'Permissions permanently denied. Please enable in Settings.',
        ));
      }
    }
  }

  Future<void> _onHistoryCleared(
    DeafModeHistoryCleared event,
    Emitter<DeafModeState> emit,
  ) async {
    transcribeSpeech.clearHistory();
    emit(state.copyWith(conversationHistory: []));
  }

  Future<void> _onSpeakText(
    DeafModeSpeakText event,
    Emitter<DeafModeState> emit,
  ) async {
    await ttsService.speak(event.text, priority: TtsPriority.normal);
  }

  @override
  Future<void> close() {
    _transcriptionSubscription?.cancel();
    _gestureSubscription?.cancel();
    _soundLevelSubscription?.cancel();
    return super.close();
  }
}
