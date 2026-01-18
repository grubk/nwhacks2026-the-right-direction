part of 'deaf_mode_bloc.dart';

enum DeafModeStatus {
  inactive,
  initializing,
  active,
  permissionRequired,
  error,
}

class DeafModeState extends Equatable {
  final DeafModeStatus status;
  final bool speechToTextEnabled;
  final bool signRecognitionEnabled;
  final bool signToSpeechEnabled;
  final bool aiEnhancementEnabled;
  final Transcription? currentTranscription;
  final SignGesture? currentGesture;
  final List<Transcription> conversationHistory;
  final double soundLevel;
  final List<AppPermission> missingPermissions;
  final String? errorMessage;

  const DeafModeState({
    this.status = DeafModeStatus.inactive,
    this.speechToTextEnabled = true,
    this.signRecognitionEnabled = false,
    this.signToSpeechEnabled = true,
    this.aiEnhancementEnabled = true,
    this.currentTranscription,
    this.currentGesture,
    this.conversationHistory = const [],
    this.soundLevel = 0,
    this.missingPermissions = const [],
    this.errorMessage,
  });

  DeafModeState copyWith({
    DeafModeStatus? status,
    bool? speechToTextEnabled,
    bool? signRecognitionEnabled,
    bool? signToSpeechEnabled,
    bool? aiEnhancementEnabled,
    Transcription? currentTranscription,
    SignGesture? currentGesture,
    List<Transcription>? conversationHistory,
    double? soundLevel,
    List<AppPermission>? missingPermissions,
    String? errorMessage,
  }) {
    return DeafModeState(
      status: status ?? this.status,
      speechToTextEnabled: speechToTextEnabled ?? this.speechToTextEnabled,
      signRecognitionEnabled: signRecognitionEnabled ?? this.signRecognitionEnabled,
      signToSpeechEnabled: signToSpeechEnabled ?? this.signToSpeechEnabled,
      aiEnhancementEnabled: aiEnhancementEnabled ?? this.aiEnhancementEnabled,
      currentTranscription: currentTranscription ?? this.currentTranscription,
      currentGesture: currentGesture ?? this.currentGesture,
      conversationHistory: conversationHistory ?? this.conversationHistory,
      soundLevel: soundLevel ?? this.soundLevel,
      missingPermissions: missingPermissions ?? this.missingPermissions,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [
    status,
    speechToTextEnabled,
    signRecognitionEnabled,
    signToSpeechEnabled,
    aiEnhancementEnabled,
    currentTranscription,
    currentGesture,
    conversationHistory,
    soundLevel,
    missingPermissions,
    errorMessage,
  ];
}
