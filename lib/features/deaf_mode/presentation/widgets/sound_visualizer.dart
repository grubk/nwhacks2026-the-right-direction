import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

/// Visual sound level indicator
/// Provides visual feedback for audio input
class SoundVisualizer extends StatelessWidget {
  final double soundLevel;

  const SoundVisualizer({
    super.key,
    required this.soundLevel,
  });

  @override
  Widget build(BuildContext context) {
    // Normalize sound level (typically -2 to 10 dB from speech_to_text)
    final normalizedLevel = ((soundLevel + 2) / 12).clamp(0.0, 1.0);
    
    return Semantics(
      label: 'Sound level indicator',
      value: '${(normalizedLevel * 100).toInt()} percent',
      child: Container(
        height: 60,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: List.generate(15, (index) {
            // Create a wave-like pattern
            final barHeight = _calculateBarHeight(index, normalizedLevel);
            
            return AnimatedContainer(
              duration: const Duration(milliseconds: 100),
              width: 6,
              height: barHeight,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(
                color: _getBarColor(normalizedLevel),
                borderRadius: BorderRadius.circular(3),
              ),
            );
          }),
        ),
      ),
    );
  }

  double _calculateBarHeight(int index, double level) {
    // Create a wave pattern that responds to sound level
    final centerIndex = 7;
    final distanceFromCenter = (index - centerIndex).abs();
    final baseFactor = 1.0 - (distanceFromCenter / centerIndex) * 0.5;
    
    // Minimum height
    const minHeight = 8.0;
    // Maximum height
    const maxHeight = 48.0;
    
    // Add some variation based on index for visual interest
    final variation = (index % 3 == 0) ? 0.1 : 0.0;
    
    final height = minHeight + (maxHeight - minHeight) * level * baseFactor + variation * maxHeight * level;
    
    return height.clamp(minHeight, maxHeight);
  }

  Color _getBarColor(double level) {
    if (level < 0.3) {
      return AppTheme.deafModeAccent.withOpacity(0.5);
    } else if (level < 0.6) {
      return AppTheme.deafModeAccent;
    } else if (level < 0.8) {
      return Colors.orange;
    } else {
      return Colors.red;
    }
  }
}
