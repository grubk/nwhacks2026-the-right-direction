/// Entity representing transcribed speech
class Transcription {
  final String text;
  final String? enhancedText;
  final double confidence;
  final bool isFinal;
  final DateTime timestamp;
  final TranscriptionSource source;
  final EmotionalContext? emotionalContext;

  const Transcription({
    required this.text,
    this.enhancedText,
    required this.confidence,
    required this.isFinal,
    required this.timestamp,
    required this.source,
    this.emotionalContext,
  });

  /// Get the best available text (enhanced if available)
  String get displayText => enhancedText ?? text;

  Transcription copyWith({
    String? text,
    String? enhancedText,
    double? confidence,
    bool? isFinal,
    DateTime? timestamp,
    TranscriptionSource? source,
    EmotionalContext? emotionalContext,
  }) {
    return Transcription(
      text: text ?? this.text,
      enhancedText: enhancedText ?? this.enhancedText,
      confidence: confidence ?? this.confidence,
      isFinal: isFinal ?? this.isFinal,
      timestamp: timestamp ?? this.timestamp,
      source: source ?? this.source,
      emotionalContext: emotionalContext ?? this.emotionalContext,
    );
  }
}

enum TranscriptionSource {
  speech,
  signLanguage,
  text,
}

class EmotionalContext {
  final EmotionalTone tone;
  final double intensity;
  final bool isUrgent;

  const EmotionalContext({
    required this.tone,
    required this.intensity,
    this.isUrgent = false,
  });
}

enum EmotionalTone {
  neutral,
  happy,
  sad,
  angry,
  anxious,
  confused,
  urgent,
}
