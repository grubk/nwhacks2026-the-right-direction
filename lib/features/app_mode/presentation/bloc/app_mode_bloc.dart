import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/services/haptic_service.dart';
import '../../domain/entities/app_mode.dart';
import '../../domain/usecases/get_app_mode.dart';
import '../../domain/usecases/set_app_mode.dart';

part 'app_mode_event.dart';
part 'app_mode_state.dart';

class AppModeBloc extends Bloc<AppModeEvent, AppModeState> {
  final GetAppMode getAppMode;
  final SetAppMode setAppMode;
  final HapticService hapticService;
  
  StreamSubscription<AppMode>? _modeSubscription;

  AppModeBloc({
    required this.getAppMode,
    required this.setAppMode,
    required this.hapticService,
  }) : super(const AppModeState()) {
    on<AppModeInitialized>(_onInitialized);
    on<AppModeToggled>(_onToggled);
    on<AppModeChanged>(_onChanged);
    on<AppModeSwipeDetected>(_onSwipeDetected);
  }

  Future<void> _onInitialized(
    AppModeInitialized event,
    Emitter<AppModeState> emit,
  ) async {
    emit(state.copyWith(status: AppModeStatus.loading));
    
    try {
      await hapticService.initialize();
      
      final mode = await getAppMode();
      
      emit(state.copyWith(
        status: AppModeStatus.loaded,
        mode: mode,
      ));
      
      // Subscribe to mode changes
      _modeSubscription = getAppMode.stream.listen((mode) {
        add(AppModeChanged(mode));
      });
    } catch (e) {
      emit(state.copyWith(
        status: AppModeStatus.error,
        errorMessage: 'Failed to load app mode: $e',
      ));
    }
  }

  Future<void> _onToggled(
    AppModeToggled event,
    Emitter<AppModeState> emit,
  ) async {
    final newMode = state.mode.toggle;
    
    try {
      await setAppMode(newMode);
      
      // Provide haptic feedback for mode switch
      final pattern = newMode == AppMode.deaf
          ? HapticPattern.deafModeActivated
          : HapticPattern.blindModeActivated;
      await hapticService.playPattern(pattern);
      
      emit(state.copyWith(
        mode: newMode,
        lastSwitchTime: DateTime.now(),
      ));
    } catch (e) {
      emit(state.copyWith(
        status: AppModeStatus.error,
        errorMessage: 'Failed to toggle mode: $e',
      ));
    }
  }

  Future<void> _onChanged(
    AppModeChanged event,
    Emitter<AppModeState> emit,
  ) async {
    emit(state.copyWith(mode: event.mode));
  }

  Future<void> _onSwipeDetected(
    AppModeSwipeDetected event,
    Emitter<AppModeState> emit,
  ) async {
    // Debounce rapid swipes
    final now = DateTime.now();
    if (state.lastSwitchTime != null &&
        now.difference(state.lastSwitchTime!).inMilliseconds < 500) {
      return;
    }
    
    add(const AppModeToggled());
  }

  @override
  Future<void> close() {
    _modeSubscription?.cancel();
    return super.close();
  }
}
