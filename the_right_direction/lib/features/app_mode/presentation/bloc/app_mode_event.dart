part of 'app_mode_bloc.dart';

abstract class AppModeEvent extends Equatable {
  const AppModeEvent();

  @override
  List<Object?> get props => [];
}

/// Initialize app mode from storage
class AppModeInitialized extends AppModeEvent {
  const AppModeInitialized();
}

/// Toggle between deaf and blind mode
class AppModeToggled extends AppModeEvent {
  const AppModeToggled();
}

/// Mode was changed (from stream)
class AppModeChanged extends AppModeEvent {
  final AppMode mode;

  const AppModeChanged(this.mode);

  @override
  List<Object?> get props => [mode];
}

/// Swipe gesture detected
class AppModeSwipeDetected extends AppModeEvent {
  final SwipeDirection direction;

  const AppModeSwipeDetected(this.direction);

  @override
  List<Object?> get props => [direction];
}

enum SwipeDirection {
  left,
  right,
}
