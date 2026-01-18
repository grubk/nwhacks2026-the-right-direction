/// Entity representing a recognized sign language gesture
class SignGesture {
  final String gesture;
  final String meaning;
  final double confidence;
  final DateTime timestamp;
  final SignLanguageType language;

  const SignGesture({
    required this.gesture,
    required this.meaning,
    required this.confidence,
    required this.timestamp,
    required this.language,
  });
}

enum SignLanguageType {
  asl, // American Sign Language
  bsl, // British Sign Language
  isl, // International Sign Language
  custom,
}

extension SignLanguageTypeExtension on SignLanguageType {
  String get displayName {
    switch (this) {
      case SignLanguageType.asl:
        return 'American Sign Language';
      case SignLanguageType.bsl:
        return 'British Sign Language';
      case SignLanguageType.isl:
        return 'International Sign';
      case SignLanguageType.custom:
        return 'Custom Signs';
    }
  }

  String get code {
    switch (this) {
      case SignLanguageType.asl:
        return 'ASL';
      case SignLanguageType.bsl:
        return 'BSL';
      case SignLanguageType.isl:
        return 'ISL';
      case SignLanguageType.custom:
        return 'Custom';
    }
  }
}
