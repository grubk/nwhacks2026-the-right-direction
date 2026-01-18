/// App Mode entity - the two primary modes of the application
enum AppMode {
  /// Deaf Mode - communication assistance
  deaf,
  
  /// Blind Mode - navigation and awareness
  blind,
}

extension AppModeExtension on AppMode {
  /// Display name for the mode
  String get displayName {
    switch (this) {
      case AppMode.deaf:
        return 'Deaf Mode';
      case AppMode.blind:
        return 'Blind Mode';
    }
  }

  /// Description of the mode
  String get description {
    switch (this) {
      case AppMode.deaf:
        return 'Communication assistance with speech-to-text and sign language recognition';
      case AppMode.blind:
        return 'Navigation assistance with object detection and haptic feedback';
    }
  }

  /// Number of vibration blips for mode confirmation
  int get vibrationBlips {
    switch (this) {
      case AppMode.deaf:
        return 2;
      case AppMode.blind:
        return 3;
    }
  }

  /// Screen reader announcement for mode switch
  String get announcement {
    switch (this) {
      case AppMode.deaf:
        return 'Switched to Deaf Mode. Speech to text and sign language recognition active.';
      case AppMode.blind:
        return 'Switched to Blind Mode. Object detection and navigation assistance active.';
    }
  }

  /// Toggle to the other mode
  AppMode get toggle {
    switch (this) {
      case AppMode.deaf:
        return AppMode.blind;
      case AppMode.blind:
        return AppMode.deaf;
    }
  }
}
