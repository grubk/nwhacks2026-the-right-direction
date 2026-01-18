import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/transcription.dart';
import '../../domain/entities/sign_gesture.dart';

/// Large, high-contrast display for current transcription
/// Designed for maximum readability
class TranscriptionDisplay extends StatelessWidget {
  final Transcription? currentTranscription;
  final SignGesture? currentGesture;

  const TranscriptionDisplay({
    super.key,
    this.currentTranscription,
    this.currentGesture,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Source indicator
          _buildSourceIndicator(),
          const SizedBox(height: 16),
          
          // Main transcription text
          Expanded(
            child: _buildTranscriptionText(),
          ),
          
          // Emotional context if available
          if (_hasEmotionalContext)
            _buildEmotionalIndicator(),
        ],
      ),
    );
  }

  Widget _buildSourceIndicator() {
    String label;
    IconData icon;
    Color color;

    if (currentGesture != null) {
      label = 'Sign Language';
      icon = Icons.sign_language;
      color = Colors.purple;
    } else if (currentTranscription != null) {
      label = 'Speech';
      icon = Icons.mic;
      color = Colors.blue;
    } else {
      label = 'Listening...';
      icon = Icons.hearing;
      color = Colors.grey;
    }

    return Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 8),
        Text(
          label,
          style: AppTheme.labelLarge.copyWith(
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
        const Spacer(),
        if (currentTranscription != null && !currentTranscription!.isFinal)
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: Colors.red,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.red.withOpacity(0.5),
                  blurRadius: 6,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildTranscriptionText() {
    String displayText;
    bool isPlaceholder = false;

    if (currentGesture != null) {
      displayText = currentGesture!.meaning;
    } else if (currentTranscription != null && currentTranscription!.text.isNotEmpty) {
      displayText = currentTranscription!.displayText;
    } else {
      displayText = 'Waiting for speech or sign...';
      isPlaceholder = true;
    }

    return Semantics(
      liveRegion: true,
      label: isPlaceholder ? 'Waiting for input' : displayText,
      child: Center(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: Text(
            displayText,
            key: ValueKey(displayText),
            style: AppTheme.headlineLarge.copyWith(
              color: isPlaceholder ? Colors.grey : Colors.black87,
              fontSize: isPlaceholder ? 24 : 28,
              fontWeight: isPlaceholder ? FontWeight.normal : FontWeight.w600,
              height: 1.3,
            ),
            textAlign: TextAlign.center,
            maxLines: 5,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }

  bool get _hasEmotionalContext {
    return currentTranscription?.emotionalContext != null &&
           currentTranscription!.emotionalContext!.tone != EmotionalTone.neutral;
  }

  Widget _buildEmotionalIndicator() {
    final context = currentTranscription!.emotionalContext!;
    
    String emoji;
    String label;
    Color color;

    switch (context.tone) {
      case EmotionalTone.happy:
        emoji = '😊';
        label = 'Happy';
        color = Colors.green;
        break;
      case EmotionalTone.sad:
        emoji = '😢';
        label = 'Sad';
        color = Colors.blue;
        break;
      case EmotionalTone.angry:
        emoji = '😠';
        label = 'Angry';
        color = Colors.red;
        break;
      case EmotionalTone.anxious:
        emoji = '😰';
        label = 'Anxious';
        color = Colors.orange;
        break;
      case EmotionalTone.confused:
        emoji = '😕';
        label = 'Confused';
        color = Colors.purple;
        break;
      case EmotionalTone.urgent:
        emoji = '🚨';
        label = 'Urgent';
        color = Colors.red;
        break;
      case EmotionalTone.neutral:
        return const SizedBox.shrink();
    }

    return Semantics(
      label: 'Detected emotion: $label',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 8),
            Text(
              label,
              style: AppTheme.labelLarge.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
