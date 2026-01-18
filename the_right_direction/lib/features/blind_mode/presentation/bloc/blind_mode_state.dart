part of 'blind_mode_bloc.dart';

enum BlindModeStatus {
  inactive,
  initializing,
  active,
  permissionRequired,
  error,
}

class BlindModeState extends Equatable {
  final BlindModeStatus status;
  final bool isDetecting;
  final bool ttsEnabled;
  final bool lidarAvailable;
  final bool lidarEnabled;
  final List<DetectedObject> currentObjects;
  final NavigationAlert? currentAlert;
  final List<AppPermission> missingPermissions;
  final String? errorMessage;

  const BlindModeState({
    this.status = BlindModeStatus.inactive,
    this.isDetecting = false,
    this.ttsEnabled = true,
    this.lidarAvailable = false,
    this.lidarEnabled = false,
    this.currentObjects = const [],
    this.currentAlert,
    this.missingPermissions = const [],
    this.errorMessage,
  });

  BlindModeState copyWith({
    BlindModeStatus? status,
    bool? isDetecting,
    bool? ttsEnabled,
    bool? lidarAvailable,
    bool? lidarEnabled,
    List<DetectedObject>? currentObjects,
    NavigationAlert? currentAlert,
    List<AppPermission>? missingPermissions,
    String? errorMessage,
  }) {
    return BlindModeState(
      status: status ?? this.status,
      isDetecting: isDetecting ?? this.isDetecting,
      ttsEnabled: ttsEnabled ?? this.ttsEnabled,
      lidarAvailable: lidarAvailable ?? this.lidarAvailable,
      lidarEnabled: lidarEnabled ?? this.lidarEnabled,
      currentObjects: currentObjects ?? this.currentObjects,
      currentAlert: currentAlert ?? this.currentAlert,
      missingPermissions: missingPermissions ?? this.missingPermissions,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [
    status,
    isDetecting,
    ttsEnabled,
    lidarAvailable,
    lidarEnabled,
    currentObjects,
    currentAlert,
    missingPermissions,
    errorMessage,
  ];
}
