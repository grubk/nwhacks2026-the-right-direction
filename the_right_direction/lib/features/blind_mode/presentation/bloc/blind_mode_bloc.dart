import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/services/camera_service.dart';
import '../../../../core/services/haptic_service.dart';
import '../../../../core/services/tts_service.dart';
import '../../../../core/services/lidar_service.dart';
import '../../../../core/services/permission_service.dart';
import '../../domain/entities/navigation_alert.dart';
import '../../domain/usecases/detect_objects.dart';

part 'blind_mode_event.dart';
part 'blind_mode_state.dart';

class BlindModeBloc extends Bloc<BlindModeEvent, BlindModeState> {
  final DetectObjects detectObjects;
  final HapticService hapticService;
  final TtsService ttsService;
  final PermissionService permissionService;
  final LidarService lidarService;

  StreamSubscription? _objectSubscription;
  StreamSubscription? _alertSubscription;
  
  // Throttle haptic feedback to avoid overwhelming the user
  DateTime? _lastHapticTime;
  static const _hapticInterval = Duration(milliseconds: 300);
  
  // Throttle TTS to avoid overlapping speech
  DateTime? _lastTtsTime;
  static const _ttsInterval = Duration(seconds: 2);

  BlindModeBloc({
    required this.detectObjects,
    required this.hapticService,
    required this.ttsService,
    required this.permissionService,
    required this.lidarService,
  }) : super(const BlindModeState()) {
    on<BlindModeStarted>(_onStarted);
    on<BlindModeStopped>(_onStopped);
    on<BlindModeObjectsDetected>(_onObjectsDetected);
    on<BlindModeAlertReceived>(_onAlertReceived);
    on<BlindModeTtsToggled>(_onTtsToggled);
    on<BlindModeLidarToggled>(_onLidarToggled);
    on<BlindModePermissionRequested>(_onPermissionRequested);
  }

  Future<void> _onStarted(
    BlindModeStarted event,
    Emitter<BlindModeState> emit,
  ) async {
    emit(state.copyWith(status: BlindModeStatus.initializing));

    try {
      // Check permissions
      final permissionStatus = await permissionService.checkBlindModePermissions();
      
      if (!permissionStatus.allGranted) {
        emit(state.copyWith(
          status: BlindModeStatus.permissionRequired,
          missingPermissions: permissionStatus.missingPermissions,
        ));
        return;
      }

      // Initialize services
      await ttsService.initialize();
      
      // Check LiDAR availability
      final lidarAvailable = await lidarService.isLidarAvailable();
      
      emit(state.copyWith(
        lidarAvailable: lidarAvailable,
        lidarEnabled: lidarAvailable, // Auto-enable if available
      ));

      // Start object detection
      await detectObjects.start();

      // Subscribe to streams
      _objectSubscription = detectObjects.objectStream.listen((objects) {
        add(BlindModeObjectsDetected(objects));
      });

      _alertSubscription = detectObjects.alertStream.listen((alert) {
        add(BlindModeAlertReceived(alert));
      });

      emit(state.copyWith(
        status: BlindModeStatus.active,
        isDetecting: true,
      ));

      // Announce mode activation
      await ttsService.speak(
        'Blind Mode activated. Object detection active.',
        priority: TtsPriority.high,
      );
    } catch (e) {
      emit(state.copyWith(
        status: BlindModeStatus.error,
        errorMessage: 'Failed to start: $e',
      ));
    }
  }

  Future<void> _onStopped(
    BlindModeStopped event,
    Emitter<BlindModeState> emit,
  ) async {
    await _objectSubscription?.cancel();
    await _alertSubscription?.cancel();
    
    await detectObjects.stop();
    await ttsService.stop();
    await hapticService.cancel();

    emit(state.copyWith(
      status: BlindModeStatus.inactive,
      isDetecting: false,
      currentObjects: [],
      currentAlert: null,
    ));
  }

  Future<void> _onObjectsDetected(
    BlindModeObjectsDetected event,
    Emitter<BlindModeState> emit,
  ) async {
    // Debug: Log detected objects and their distances
    if (event.objects.isNotEmpty) {
      print('[BlindMode DEBUG] Detected ${event.objects.length} object(s):');
      for (final obj in event.objects) {
        print('  - ${obj.label}: ${obj.distance.toStringAsFixed(2)}m (${obj.direction.name})');
      }
    }
    
    emit(state.copyWith(currentObjects: event.objects));
  }

  Future<void> _onAlertReceived(
    BlindModeAlertReceived event,
    Emitter<BlindModeState> emit,
  ) async {
    final alert = event.alert;
    
    emit(state.copyWith(currentAlert: alert));

    // Provide haptic feedback based on proximity
    await _provideHapticFeedback(alert);

    // Provide TTS guidance
    if (state.ttsEnabled && alert.level != NavigationAlertLevel.clear) {
      await _provideTtsGuidance(alert);
    }
  }

  Future<void> _provideHapticFeedback(NavigationAlert alert) async {
    // Throttle haptic feedback
    final now = DateTime.now();
    if (_lastHapticTime != null &&
        now.difference(_lastHapticTime!) < _hapticInterval) {
      return;
    }
    _lastHapticTime = now;

    HapticPattern pattern;
    
    switch (alert.level) {
      case NavigationAlertLevel.clear:
        return; // No haptic for clear path
      case NavigationAlertLevel.low:
        pattern = HapticPattern.proximityFar;
        break;
      case NavigationAlertLevel.moderate:
        pattern = HapticPattern.proximityMedium;
        break;
      case NavigationAlertLevel.high:
        pattern = HapticPattern.proximityClose;
        break;
      case NavigationAlertLevel.critical:
        pattern = HapticPattern.proximityVeryClose;
        break;
    }

    // Debug: Log vibration feedback
    final distanceInfo = alert.closestObject != null
        ? ' (closest: ${alert.closestObject!.label} at ${alert.closestObject!.distance.toStringAsFixed(2)}m)'
        : '';
    print('[BlindMode DEBUG] VIBRATING: ${pattern.name} - Alert level: ${alert.level.name}$distanceInfo');

    await hapticService.playPattern(pattern);

    // Also provide directional feedback
    if (alert.closestObject != null) {
      await _provideDirectionalFeedback(alert.closestObject!.direction);
    }
  }

  Future<void> _provideDirectionalFeedback(ObjectDirection direction) async {
    // Wait a moment before directional feedback
    await Future.delayed(const Duration(milliseconds: 150));

    switch (direction) {
      case ObjectDirection.left:
        print('[BlindMode DEBUG] VIBRATING: Directional feedback - LEFT');
        await hapticService.playPattern(HapticPattern.directionLeft);
        break;
      case ObjectDirection.right:
        print('[BlindMode DEBUG] VIBRATING: Directional feedback - RIGHT');
        await hapticService.playPattern(HapticPattern.directionRight);
        break;
      case ObjectDirection.center:
        print('[BlindMode DEBUG] VIBRATING: Directional feedback - CENTER');
        await hapticService.playPattern(HapticPattern.directionCenter);
        break;
      case ObjectDirection.unknown:
        break;
    }
  }

  Future<void> _provideTtsGuidance(NavigationAlert alert) async {
    if (alert.spokenGuidance.isEmpty) return;

    // Throttle TTS
    final now = DateTime.now();
    
    // Always speak critical alerts
    if (alert.level != NavigationAlertLevel.critical) {
      if (_lastTtsTime != null &&
          now.difference(_lastTtsTime!) < _ttsInterval) {
        return;
      }
    }
    _lastTtsTime = now;

    final priority = alert.level == NavigationAlertLevel.critical
        ? TtsPriority.critical
        : TtsPriority.normal;

    await ttsService.speak(alert.spokenGuidance, priority: priority);
  }

  Future<void> _onTtsToggled(
    BlindModeTtsToggled event,
    Emitter<BlindModeState> emit,
  ) async {
    final newState = !state.ttsEnabled;
    emit(state.copyWith(ttsEnabled: newState));
    
    await detectObjects.setTtsEnabled(newState);
    
    // Announce the change
    if (newState) {
      await ttsService.speak('Voice guidance on');
    } else {
      await ttsService.speak('Voice guidance off');
    }
  }

  Future<void> _onLidarToggled(
    BlindModeLidarToggled event,
    Emitter<BlindModeState> emit,
  ) async {
    if (!state.lidarAvailable) return;

    final newState = !state.lidarEnabled;
    emit(state.copyWith(lidarEnabled: newState));
    
    await detectObjects.setLidarEnabled(newState);
    
    // Announce the change
    if (state.ttsEnabled) {
      final message = newState ? 'LiDAR sensing enabled' : 'LiDAR sensing disabled';
      await ttsService.speak(message);
    }
  }

  Future<void> _onPermissionRequested(
    BlindModePermissionRequested event,
    Emitter<BlindModeState> emit,
  ) async {
    final results = await permissionService.requestBlindModePermissions();
    
    final allGranted = results.values.every(
      (r) => r == PermissionResult.granted,
    );
    
    if (allGranted) {
      add(const BlindModeStarted());
    } else {
      // Check for permanently denied
      final hasPermanentlyDenied = results.values.any(
        (r) => r == PermissionResult.permanentlyDenied,
      );
      
      if (hasPermanentlyDenied) {
        emit(state.copyWith(
          status: BlindModeStatus.error,
          errorMessage: 'Camera permission permanently denied. Please enable in Settings.',
        ));
      }
    }
  }

  @override
  Future<void> close() {
    _objectSubscription?.cancel();
    _alertSubscription?.cancel();
    return super.close();
  }
}
