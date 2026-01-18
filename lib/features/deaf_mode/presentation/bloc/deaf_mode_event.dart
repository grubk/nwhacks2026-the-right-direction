part of 'deaf_mode_bloc.dart';

abstract class DeafModeEvent extends Equatable {
  const DeafModeEvent();

  @override
  List<Object?> get props => [];
}

/// Start deaf mode
class DeafModeStarted extends DeafModeEvent {
  const DeafModeStarted();
}

/// Stop deaf mode
class DeafModeStopped extends DeafModeEvent {
  const DeafModeStopped();
}

/// Transcription received
class DeafModeTranscriptionReceived extends DeafModeEvent {
  final Transcription transcription;

  const DeafModeTranscriptionReceived(this.transcription);

  @override
  List<Object?> get props => [transcription];
}

/// Sign gesture recognized
class DeafModeGestureRecognized extends DeafModeEvent {
  final SignGesture gesture;

  const DeafModeGestureRecognized(this.gesture);

  @override
  List<Object?> get props => [gesture];
}

/// Sound level changed (for visual feedback)
class DeafModeSoundLevelChanged extends DeafModeEvent {
  final double level;

  const DeafModeSoundLevelChanged(this.level);

  @override
  List<Object?> get props => [level];
}

/// Toggle feature
class DeafModeFeatureToggled extends DeafModeEvent {
  final DeafModeFeature feature;

  const DeafModeFeatureToggled(this.feature);

  @override
  List<Object?> get props => [feature];
}

/// Request permissions
class DeafModePermissionRequested extends DeafModeEvent {
  const DeafModePermissionRequested();
}

/// Clear conversation history
class DeafModeHistoryCleared extends DeafModeEvent {
  const DeafModeHistoryCleared();
}

/// Speak text aloud (for sign language output)
class DeafModeSpeakText extends DeafModeEvent {
  final String text;

  const DeafModeSpeakText(this.text);

  @override
  List<Object?> get props => [text];
}

enum DeafModeFeature {
  speechToText,
  signRecognition,
  signToSpeech,
  aiEnhancement,
}
