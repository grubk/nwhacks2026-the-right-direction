part of 'blind_mode_bloc.dart';

abstract class BlindModeEvent extends Equatable {
  const BlindModeEvent();

  @override
  List<Object?> get props => [];
}

/// Start blind mode detection
class BlindModeStarted extends BlindModeEvent {
  const BlindModeStarted();
}

/// Stop blind mode detection
class BlindModeStopped extends BlindModeEvent {
  const BlindModeStopped();
}

/// Objects detected in camera frame
class BlindModeObjectsDetected extends BlindModeEvent {
  final List<DetectedObject> objects;

  const BlindModeObjectsDetected(this.objects);

  @override
  List<Object?> get props => [objects];
}

/// Navigation alert received
class BlindModeAlertReceived extends BlindModeEvent {
  final NavigationAlert alert;

  const BlindModeAlertReceived(this.alert);

  @override
  List<Object?> get props => [alert];
}

/// Toggle TTS guidance
class BlindModeTtsToggled extends BlindModeEvent {
  const BlindModeTtsToggled();
}

/// Toggle LiDAR sensing (iOS only)
class BlindModeLidarToggled extends BlindModeEvent {
  const BlindModeLidarToggled();
}

/// Request permissions
class BlindModePermissionRequested extends BlindModeEvent {
  const BlindModePermissionRequested();
}
