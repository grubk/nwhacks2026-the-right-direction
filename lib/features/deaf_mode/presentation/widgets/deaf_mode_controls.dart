import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../bloc/deaf_mode_bloc.dart';

/// Accessible controls for deaf mode features
class DeafModeControls extends StatelessWidget {
  final bool speechToTextEnabled;
  final bool signRecognitionEnabled;
  final bool signToSpeechEnabled;
  final bool aiEnhancementEnabled;
  final void Function(DeafModeFeature) onFeatureToggle;

  const DeafModeControls({
    super.key,
    required this.speechToTextEnabled,
    required this.signRecognitionEnabled,
    required this.signToSpeechEnabled,
    required this.aiEnhancementEnabled,
    required this.onFeatureToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Main controls row
            Row(
              children: [
                Expanded(
                  child: _buildControlButton(
                    icon: Icons.mic,
                    label: 'Speech',
                    isEnabled: speechToTextEnabled,
                    onPressed: () => onFeatureToggle(DeafModeFeature.speechToText),
                    semanticLabel: speechToTextEnabled
                        ? 'Speech to text is on. Double tap to turn off.'
                        : 'Speech to text is off. Double tap to turn on.',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildControlButton(
                    icon: Icons.sign_language,
                    label: 'Signs',
                    isEnabled: signRecognitionEnabled,
                    onPressed: () => onFeatureToggle(DeafModeFeature.signRecognition),
                    semanticLabel: signRecognitionEnabled
                        ? 'Sign recognition is on. Double tap to turn off.'
                        : 'Sign recognition is off. Double tap to turn on.',
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // Secondary controls row
            Row(
              children: [
                Expanded(
                  child: _buildControlButton(
                    icon: Icons.record_voice_over,
                    label: 'Voice Out',
                    isEnabled: signToSpeechEnabled,
                    onPressed: () => onFeatureToggle(DeafModeFeature.signToSpeech),
                    semanticLabel: signToSpeechEnabled
                        ? 'Sign to speech is on. Double tap to turn off.'
                        : 'Sign to speech is off. Double tap to turn on.',
                    isSmall: true,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildControlButton(
                    icon: Icons.auto_awesome,
                    label: 'AI Enhance',
                    isEnabled: aiEnhancementEnabled,
                    onPressed: () => onFeatureToggle(DeafModeFeature.aiEnhancement),
                    semanticLabel: aiEnhancementEnabled
                        ? 'AI enhancement is on. Double tap to turn off.'
                        : 'AI enhancement is off. Double tap to turn on.',
                    isSmall: true,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Swipe hint
            Semantics(
              label: 'Swipe left or right anywhere to switch to Blind Mode',
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.swipe,
                      color: Colors.white54,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Swipe to switch mode',
                      style: AppTheme.labelLarge.copyWith(
                        color: Colors.white54,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required bool isEnabled,
    required VoidCallback onPressed,
    required String semanticLabel,
    bool isSmall = false,
  }) {
    final height = isSmall ? 56.0 : AppTheme.largeTouchTarget;
    final iconSize = isSmall ? 24.0 : 28.0;
    final fontSize = isSmall ? 14.0 : 16.0;

    return Semantics(
      label: semanticLabel,
      button: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            height: height,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: isEnabled
                  ? AppTheme.deafModeAccent.withOpacity(0.2)
                  : Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isEnabled
                    ? AppTheme.deafModeAccent
                    : Colors.white24,
                width: 2,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  color: isEnabled ? AppTheme.deafModeAccent : Colors.white54,
                  size: iconSize,
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    color: isEnabled ? AppTheme.deafModeAccent : Colors.white54,
                    fontWeight: FontWeight.bold,
                    fontSize: fontSize,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
