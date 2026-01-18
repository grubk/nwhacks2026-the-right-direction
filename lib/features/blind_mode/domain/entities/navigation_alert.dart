import '../../../../core/services/camera_service.dart';

/// Entity representing a navigation alert for blind users
class NavigationAlert {
  final List<DetectedObject> objects;
  final DetectedObject? closestObject;
  final NavigationAlertLevel level;
  final String spokenGuidance;
  final DateTime timestamp;

  const NavigationAlert({
    required this.objects,
    this.closestObject,
    required this.level,
    required this.spokenGuidance,
    required this.timestamp,
  });

  /// Whether this alert requires immediate attention
  bool get isUrgent => level == NavigationAlertLevel.critical ||
                        level == NavigationAlertLevel.high;
}

enum NavigationAlertLevel {
  /// No obstacles detected
  clear,
  
  /// Objects detected but far away (> 2m)
  low,
  
  /// Objects at medium distance (1-2m)
  moderate,
  
  /// Objects close (0.5-1m) - exercise caution
  high,
  
  /// Objects very close (< 0.5m) - immediate danger
  critical,
}

extension NavigationAlertLevelExtension on NavigationAlertLevel {
  String get description {
    switch (this) {
      case NavigationAlertLevel.clear:
        return 'Path is clear';
      case NavigationAlertLevel.low:
        return 'Objects detected ahead';
      case NavigationAlertLevel.moderate:
        return 'Approaching object';
      case NavigationAlertLevel.high:
        return 'Object nearby';
      case NavigationAlertLevel.critical:
        return 'Obstacle ahead';
    }
  }
}
