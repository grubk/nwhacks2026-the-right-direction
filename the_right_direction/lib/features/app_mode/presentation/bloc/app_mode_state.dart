part of 'app_mode_bloc.dart';

enum AppModeStatus {
  initial,
  loading,
  loaded,
  error,
}

class AppModeState extends Equatable {
  final AppModeStatus status;
  final AppMode mode;
  final DateTime? lastSwitchTime;
  final String? errorMessage;

  const AppModeState({
    this.status = AppModeStatus.initial,
    this.mode = AppMode.deaf,
    this.lastSwitchTime,
    this.errorMessage,
  });

  AppModeState copyWith({
    AppModeStatus? status,
    AppMode? mode,
    DateTime? lastSwitchTime,
    String? errorMessage,
  }) {
    return AppModeState(
      status: status ?? this.status,
      mode: mode ?? this.mode,
      lastSwitchTime: lastSwitchTime ?? this.lastSwitchTime,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, mode, lastSwitchTime, errorMessage];
}
