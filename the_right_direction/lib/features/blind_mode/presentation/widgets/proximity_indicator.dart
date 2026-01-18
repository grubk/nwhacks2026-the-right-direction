import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/navigation_alert.dart';

/// Visual proximity indicator for blind mode
/// Shows full-screen color feedback based on obstacle distance
/// Designed for users with partial vision
class ProximityIndicator extends StatelessWidget {
  final NavigationAlert? alert;

  const ProximityIndicator({
    super.key,
    this.alert,
  });

  @override
  Widget build(BuildContext context) {
    final level = alert?.level ?? NavigationAlertLevel.clear;
    
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        gradient: _buildGradient(level),
      ),
      child: Center(
        child: _buildIndicator(level),
      ),
    );
  }

  LinearGradient _buildGradient(NavigationAlertLevel level) {
    final color = _getLevelColor(level);
    
    return LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        color.withOpacity(0.3),
        color.withOpacity(0.1),
        Colors.black,
      ],
      stops: const [0.0, 0.3, 1.0],
    );
  }

  Color _getLevelColor(NavigationAlertLevel level) {
    switch (level) {
      case NavigationAlertLevel.clear:
        return AppTheme.blindModeAccent; // Green
      case NavigationAlertLevel.low:
        return Colors.lightGreen;
      case NavigationAlertLevel.moderate:
        return Colors.yellow;
      case NavigationAlertLevel.high:
        return Colors.orange;
      case NavigationAlertLevel.critical:
        return Colors.red;
    }
  }

  Widget _buildIndicator(NavigationAlertLevel level) {
    final color = _getLevelColor(level);
    final size = _getIndicatorSize(level);
    
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withOpacity(0.2),
        border: Border.all(
          color: color,
          width: 4,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.5),
            blurRadius: 30,
            spreadRadius: 10,
          ),
        ],
      ),
      child: Center(
        child: _buildCenterIcon(level, color),
      ),
    );
  }

  double _getIndicatorSize(NavigationAlertLevel level) {
    switch (level) {
      case NavigationAlertLevel.clear:
        return 100;
      case NavigationAlertLevel.low:
        return 120;
      case NavigationAlertLevel.moderate:
        return 150;
      case NavigationAlertLevel.high:
        return 180;
      case NavigationAlertLevel.critical:
        return 220;
    }
  }

  Widget _buildCenterIcon(NavigationAlertLevel level, Color color) {
    IconData icon;
    double iconSize;
    
    switch (level) {
      case NavigationAlertLevel.clear:
        icon = Icons.check;
        iconSize = 48;
        break;
      case NavigationAlertLevel.low:
        icon = Icons.remove_red_eye;
        iconSize = 48;
        break;
      case NavigationAlertLevel.moderate:
        icon = Icons.warning_amber;
        iconSize = 56;
        break;
      case NavigationAlertLevel.high:
        icon = Icons.warning;
        iconSize = 64;
        break;
      case NavigationAlertLevel.critical:
        icon = Icons.pan_tool;
        iconSize = 80;
        break;
    }

    return Icon(
      icon,
      color: color,
      size: iconSize,
    );
  }
}
