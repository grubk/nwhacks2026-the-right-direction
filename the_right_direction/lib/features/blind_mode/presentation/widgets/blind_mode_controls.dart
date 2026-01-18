import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

/// Accessible controls for blind mode settings
class BlindModeControls extends StatelessWidget {
  final bool ttsEnabled;
  final bool lidarAvailable;
  final bool lidarEnabled;
  final VoidCallback onTtsToggle;
  final VoidCallback onLidarToggle;

  const BlindModeControls({
    super.key,
    required this.ttsEnabled,
    required this.lidarAvailable,
    required this.lidarEnabled,
    required this.onTtsToggle,
    required this.onLidarToggle,
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
            // TTS Toggle
            _buildControlButton(
              icon: ttsEnabled ? Icons.volume_up : Icons.volume_off,
              label: ttsEnabled ? 'Voice On' : 'Voice Off',
              isEnabled: ttsEnabled,
              onPressed: onTtsToggle,
              semanticLabel: ttsEnabled
                  ? 'Voice guidance is on. Double tap to turn off.'
                  : 'Voice guidance is off. Double tap to turn on.',
            ),
            
            if (lidarAvailable) ...[
              const SizedBox(height: 12),
              _buildControlButton(
                icon: Icons.sensors,
                label: lidarEnabled ? 'LiDAR On' : 'LiDAR Off',
                isEnabled: lidarEnabled,
                onPressed: onLidarToggle,
                semanticLabel: lidarEnabled
                    ? 'LiDAR is on. Double tap to turn off.'
                    : 'LiDAR is off. Double tap to turn on.',
              ),
            ],
            
            const SizedBox(height: 16),
            
            // Swipe hint
            Semantics(
              label: 'Swipe left or right anywhere to switch to Deaf Mode',
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
  }) {
    return Semantics(
      label: semanticLabel,
      button: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
            decoration: BoxDecoration(
              color: isEnabled
                  ? AppTheme.blindModeAccent.withOpacity(0.2)
                  : Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isEnabled
                    ? AppTheme.blindModeAccent
                    : Colors.white24,
                width: 2,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  color: isEnabled ? AppTheme.blindModeAccent : Colors.white54,
                  size: 32,
                ),
                const SizedBox(width: 16),
                Text(
                  label,
                  style: AppTheme.bodyLarge.copyWith(
                    color: isEnabled ? AppTheme.blindModeAccent : Colors.white54,
                    fontWeight: FontWeight.bold,
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
