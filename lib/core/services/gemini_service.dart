import 'dart:async';
import 'package:google_generative_ai/google_generative_ai.dart';

/// Gemini AI service for enhanced transcription and understanding
/// Used to improve speech-to-text accuracy and provide semantic context
abstract class GeminiService {
  /// Initialize Gemini API
  Future<void> initialize(String apiKey);
  
  /// Check if service is available
  bool get isAvailable;
  
  /// Enhance transcription with context and clarity
  Future<EnhancedTranscription> enhanceTranscription(
    String rawTranscription, {
    String? context,
    String? previousTranscription,
  });
  
  /// Summarize conversation
  Future<String> summarizeConversation(List<String> transcriptions);
  
  /// Detect intent from speech
  Future<IntentResult> detectIntent(String transcription);
  
  /// Generate response suggestions
  Future<List<String>> generateResponseSuggestions(String transcription);
  
  /// Check if text contains urgent/emergency content
  Future<bool> isUrgentContent(String text);
  
  /// Translate text
  Future<String> translate(String text, String targetLanguage);
  
  /// Dispose resources
  Future<void> dispose();
}

class EnhancedTranscription {
  final String original;
  final String enhanced;
  final double confidenceImprovement;
  final List<String> corrections;
  final String? summary;
  final bool hasEmotionalContent;
  final EmotionalTone? emotionalTone;

  const EnhancedTranscription({
    required this.original,
    required this.enhanced,
    required this.confidenceImprovement,
    this.corrections = const [],
    this.summary,
    this.hasEmotionalContent = false,
    this.emotionalTone,
  });
}

class IntentResult {
  final String intent;
  final double confidence;
  final Map<String, dynamic> entities;
  final bool isQuestion;
  final bool requiresResponse;

  const IntentResult({
    required this.intent,
    required this.confidence,
    this.entities = const {},
    this.isQuestion = false,
    this.requiresResponse = false,
  });
}

enum EmotionalTone {
  neutral,
  happy,
  sad,
  angry,
  anxious,
  urgent,
  confused,
}

class GeminiServiceImpl implements GeminiService {
  GenerativeModel? _model;
  ChatSession? _chatSession;
  bool _isAvailable = false;

  @override
  bool get isAvailable => _isAvailable;

  @override
  Future<void> initialize(String apiKey) async {
    if (apiKey.isEmpty) {
      _isAvailable = false;
      return;
    }

    try {
      _model = GenerativeModel(
        model: 'gemini-1.5-flash',
        apiKey: apiKey,
        generationConfig: GenerationConfig(
          temperature: 0.3, // Lower temperature for more consistent output
          maxOutputTokens: 500,
        ),
        systemInstruction: Content.text('''
You are an AI assistant specialized in helping deaf individuals communicate more effectively.
Your primary tasks are:
1. Enhance speech-to-text transcriptions for clarity and accuracy
2. Correct common misheard words and phrases
3. Identify emotional tone in speech
4. Summarize conversations concisely
5. Detect urgent or emergency content
Always be concise and helpful. Prioritize clarity and accessibility.
'''),
      );

      _chatSession = _model!.startChat();
      _isAvailable = true;
    } catch (e) {
      _isAvailable = false;
    }
  }

  @override
  Future<EnhancedTranscription> enhanceTranscription(
    String rawTranscription, {
    String? context,
    String? previousTranscription,
  }) async {
    if (!_isAvailable || rawTranscription.isEmpty) {
      return EnhancedTranscription(
        original: rawTranscription,
        enhanced: rawTranscription,
        confidenceImprovement: 0,
      );
    }

    try {
      final prompt = '''
Enhance this speech-to-text transcription for clarity. Fix any obvious errors or misheard words.

Raw transcription: "$rawTranscription"
${context != null ? 'Context: $context' : ''}
${previousTranscription != null ? 'Previous: $previousTranscription' : ''}

Respond in JSON format:
{
  "enhanced": "corrected text",
  "corrections": ["list of corrections made"],
  "emotionalTone": "neutral|happy|sad|angry|anxious|urgent|confused",
  "summary": "brief summary if text is long"
}
''';

      final response = await _model!.generateContent([Content.text(prompt)]);
      final text = response.text ?? '';

      // Parse JSON response
      try {
        // Simple JSON parsing - production would use proper JSON parser
        final enhanced = _extractJsonValue(text, 'enhanced') ?? rawTranscription;
        final corrections = _extractJsonArray(text, 'corrections');
        final toneStr = _extractJsonValue(text, 'emotionalTone') ?? 'neutral';
        final summary = _extractJsonValue(text, 'summary');

        return EnhancedTranscription(
          original: rawTranscription,
          enhanced: enhanced,
          confidenceImprovement: corrections.isNotEmpty ? 0.2 : 0,
          corrections: corrections,
          summary: summary,
          hasEmotionalContent: toneStr != 'neutral',
          emotionalTone: _parseEmotionalTone(toneStr),
        );
      } catch (e) {
        // Fallback if JSON parsing fails
        return EnhancedTranscription(
          original: rawTranscription,
          enhanced: rawTranscription,
          confidenceImprovement: 0,
        );
      }
    } catch (e) {
      return EnhancedTranscription(
        original: rawTranscription,
        enhanced: rawTranscription,
        confidenceImprovement: 0,
      );
    }
  }

  @override
  Future<String> summarizeConversation(List<String> transcriptions) async {
    if (!_isAvailable || transcriptions.isEmpty) {
      return '';
    }

    try {
      final prompt = '''
Summarize this conversation in 2-3 concise sentences:

${transcriptions.asMap().entries.map((e) => '${e.key + 1}. ${e.value}').join('\n')}

Provide only the summary, no other text.
''';

      final response = await _model!.generateContent([Content.text(prompt)]);
      return response.text?.trim() ?? '';
    } catch (e) {
      return '';
    }
  }

  @override
  Future<IntentResult> detectIntent(String transcription) async {
    if (!_isAvailable || transcription.isEmpty) {
      return const IntentResult(
        intent: 'unknown',
        confidence: 0,
      );
    }

    try {
      final prompt = '''
Analyze this transcription and detect the speaker's intent:

"$transcription"

Respond in JSON format:
{
  "intent": "greeting|question|request|statement|command|emergency|unknown",
  "confidence": 0.0-1.0,
  "isQuestion": true|false,
  "requiresResponse": true|false,
  "entities": {"key": "value"}
}
''';

      final response = await _model!.generateContent([Content.text(prompt)]);
      final text = response.text ?? '';

      return IntentResult(
        intent: _extractJsonValue(text, 'intent') ?? 'unknown',
        confidence: double.tryParse(_extractJsonValue(text, 'confidence') ?? '0') ?? 0,
        isQuestion: _extractJsonValue(text, 'isQuestion') == 'true',
        requiresResponse: _extractJsonValue(text, 'requiresResponse') == 'true',
      );
    } catch (e) {
      return const IntentResult(
        intent: 'unknown',
        confidence: 0,
      );
    }
  }

  @override
  Future<List<String>> generateResponseSuggestions(String transcription) async {
    if (!_isAvailable || transcription.isEmpty) {
      return [];
    }

    try {
      final prompt = '''
Generate 3 short, helpful response suggestions for this:

"$transcription"

Respond with only 3 responses, one per line, no numbering or bullets.
''';

      final response = await _model!.generateContent([Content.text(prompt)]);
      final text = response.text ?? '';

      return text.split('\n')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .take(3)
          .toList();
    } catch (e) {
      return [];
    }
  }

  @override
  Future<bool> isUrgentContent(String text) async {
    if (!_isAvailable || text.isEmpty) {
      return false;
    }

    // Quick local check for common emergency words
    final urgentKeywords = [
      'help', 'emergency', 'fire', 'police', 'ambulance',
      'danger', 'hurt', 'pain', 'attack', 'accident',
      'call 911', 'urgent', 'immediately', 'now',
    ];

    final lowerText = text.toLowerCase();
    for (final keyword in urgentKeywords) {
      if (lowerText.contains(keyword)) {
        return true;
      }
    }

    // Use AI for more nuanced detection if no obvious keywords
    try {
      final prompt = '''
Is this text expressing an emergency or urgent situation requiring immediate attention?
"$text"
Respond with only "yes" or "no".
''';

      final response = await _model!.generateContent([Content.text(prompt)]);
      return response.text?.toLowerCase().contains('yes') ?? false;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<String> translate(String text, String targetLanguage) async {
    if (!_isAvailable || text.isEmpty) {
      return text;
    }

    try {
      final prompt = '''
Translate this text to $targetLanguage:
"$text"
Provide only the translation, no other text.
''';

      final response = await _model!.generateContent([Content.text(prompt)]);
      return response.text?.trim() ?? text;
    } catch (e) {
      return text;
    }
  }

  String? _extractJsonValue(String json, String key) {
    final pattern = RegExp('"$key"\\s*:\\s*"?([^",}]+)"?');
    final match = pattern.firstMatch(json);
    return match?.group(1)?.trim();
  }

  List<String> _extractJsonArray(String json, String key) {
    final pattern = RegExp('"$key"\\s*:\\s*\\[([^\\]]+)\\]');
    final match = pattern.firstMatch(json);
    if (match == null) return [];

    return match.group(1)!
        .split(',')
        .map((s) => s.trim().replaceAll('"', ''))
        .where((s) => s.isNotEmpty)
        .toList();
  }

  EmotionalTone? _parseEmotionalTone(String tone) {
    switch (tone.toLowerCase()) {
      case 'happy':
        return EmotionalTone.happy;
      case 'sad':
        return EmotionalTone.sad;
      case 'angry':
        return EmotionalTone.angry;
      case 'anxious':
        return EmotionalTone.anxious;
      case 'urgent':
        return EmotionalTone.urgent;
      case 'confused':
        return EmotionalTone.confused;
      case 'neutral':
      default:
        return EmotionalTone.neutral;
    }
  }

  @override
  Future<void> dispose() async {
    _chatSession = null;
    _model = null;
    _isAvailable = false;
  }
}
