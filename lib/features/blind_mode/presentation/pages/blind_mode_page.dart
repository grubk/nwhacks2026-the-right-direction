import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/navigation_alert.dart';
import '../bloc/blind_mode_bloc.dart';
import '../widgets/proximity_indicator.dart';
import '../widgets/object_overlay.dart';
import '../widgets/blind_mode_controls.dart';

class BlindModePage extends StatefulWidget {
  const BlindModePage({super.key});

  @override
  State<BlindModePage> createState() => _BlindModePageState();
}

class _BlindModePageState extends State<BlindModePage> with WidgetsBindingObserver {
  late BlindModeBloc _bloc;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _bloc = getIt<BlindModeBloc>();
    _bloc.add(const BlindModeStarted());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _bloc.add(const BlindModeStopped());
    } else if (state == AppLifecycleState.resumed) {
      _bloc.add(const BlindModeStarted());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _bloc.add(const BlindModeStopped());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _bloc,
      child: BlocBuilder<BlindModeBloc, BlindModeState>(
        builder: (context, state) {
          return Scaffold(
            backgroundColor: AppTheme.blindModeBackground,
            body: SafeArea(
              child: _buildContent(context, state),
            ),
          );
        },
      ),
    );
  }

  Widget _buildContent(BuildContext context, BlindModeState state) {
    switch (state.status) {
      case BlindModeStatus.inactive:
      case BlindModeStatus.initializing:
        return _buildLoadingView();
      case BlindModeStatus.permissionRequired:
        return _buildPermissionView(context, state);
      case BlindModeStatus.error:
        return _buildErrorView(context, state);
      case BlindModeStatus.active:
        return _buildActiveView(context, state);
    }
  }

  Widget _buildLoadingView() {
    return Semantics(
      label: 'Initializing Blind Mode. Please wait.',
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(
              color: AppTheme.blindModeAccent,
              strokeWidth: 4,
            ),
            const SizedBox(height: 24),
            Text(
              'Initializing...',
              style: AppTheme.headlineMedium.copyWith(
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionView(BuildContext context, BlindModeState state) {
    return Semantics(
      label: 'Camera permission required for Blind Mode. Double tap anywhere to grant permission.',
      child: GestureDetector(
        onDoubleTap: () {
          context.read<BlindModeBloc>().add(const BlindModePermissionRequested());
        },
        child: Container(
          width: double.infinity,
          height: double.infinity,
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.camera_alt,
                size: 80,
                color: AppTheme.blindModeAccent,
              ),
              const SizedBox(height: 24),
              Text(
                'Camera Access Required',
                style: AppTheme.headlineMedium.copyWith(
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'Blind Mode needs camera access to detect objects and help you navigate.',
                style: AppTheme.bodyLarge.copyWith(
                  color: Colors.white70,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: AppTheme.largeTouchTarget,
                child: ElevatedButton(
                  onPressed: () {
                    context.read<BlindModeBloc>().add(const BlindModePermissionRequested());
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.blindModeAccent,
                    foregroundColor: Colors.black,
                  ),
                  child: const Text(
                    'Grant Permission',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorView(BuildContext context, BlindModeState state) {
    return Semantics(
      label: 'Error: ${state.errorMessage}. Double tap to retry.',
      child: GestureDetector(
        onDoubleTap: () {
          context.read<BlindModeBloc>().add(const BlindModeStarted());
        },
        child: Container(
          width: double.infinity,
          height: double.infinity,
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 80,
                color: AppTheme.errorColor,
              ),
              const SizedBox(height: 24),
              Text(
                'Something Went Wrong',
                style: AppTheme.headlineMedium.copyWith(
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                state.errorMessage ?? 'Unknown error occurred',
                style: AppTheme.bodyLarge.copyWith(
                  color: Colors.white70,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: AppTheme.largeTouchTarget,
                child: ElevatedButton(
                  onPressed: () {
                    context.read<BlindModeBloc>().add(const BlindModeStarted());
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.blindModeAccent,
                    foregroundColor: Colors.black,
                  ),
                  child: const Text(
                    'Retry',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActiveView(BuildContext context, BlindModeState state) {
    return Semantics(
      liveRegion: true,
      label: _getAccessibilityLabel(state),
      child: Stack(
        children: [
          // Full-screen proximity indicator
          Positioned.fill(
            child: ProximityIndicator(alert: state.currentAlert),
          ),
          
          // Object overlays (for users with partial vision)
          if (state.currentObjects.isNotEmpty)
            Positioned.fill(
              child: ObjectOverlay(objects: state.currentObjects),
            ),
          
          // Controls at bottom
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: BlindModeControls(
              ttsEnabled: state.ttsEnabled,
              lidarAvailable: state.lidarAvailable,
              lidarEnabled: state.lidarEnabled,
              onTtsToggle: () {
                context.read<BlindModeBloc>().add(const BlindModeTtsToggled());
              },
              onLidarToggle: () {
                context.read<BlindModeBloc>().add(const BlindModeLidarToggled());
              },
            ),
          ),
          
          // Mode indicator at top
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: _buildModeIndicator(state),
          ),
        ],
      ),
    );
  }

  Widget _buildModeIndicator(BlindModeState state) {
    return Semantics(
      label: 'Blind Mode active. ${state.lidarEnabled ? "LiDAR enabled." : ""} '
             'Swipe left or right to switch to Deaf Mode.',
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.visibility,
              color: AppTheme.blindModeAccent,
              size: 28,
            ),
            const SizedBox(width: 12),
            Text(
              'BLIND MODE',
              style: AppTheme.labelLarge.copyWith(
                color: AppTheme.blindModeAccent,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
            ),
            if (state.lidarEnabled) ...[
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.blindModeAccent.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'LiDAR',
                  style: AppTheme.labelLarge.copyWith(
                    color: AppTheme.blindModeAccent,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _getAccessibilityLabel(BlindModeState state) {
    if (state.currentAlert == null) {
      return 'Blind Mode active. Scanning for objects.';
    }

    final alert = state.currentAlert!;
    switch (alert.level) {
      case NavigationAlertLevel.clear:
        return 'Path is clear. No obstacles detected.';
      case NavigationAlertLevel.low:
      case NavigationAlertLevel.moderate:
      case NavigationAlertLevel.high:
      case NavigationAlertLevel.critical:
        return alert.spokenGuidance;
    }
  }
}
