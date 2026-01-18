import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/app_theme.dart';
import '../bloc/deaf_mode_bloc.dart';
import '../widgets/transcription_display.dart';
import '../widgets/sound_visualizer.dart';
import '../widgets/deaf_mode_controls.dart';
import '../widgets/conversation_history.dart';

class DeafModePage extends StatefulWidget {
  const DeafModePage({super.key});

  @override
  State<DeafModePage> createState() => _DeafModePageState();
}

class _DeafModePageState extends State<DeafModePage> with WidgetsBindingObserver {
  late DeafModeBloc _bloc;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _bloc = getIt<DeafModeBloc>();
    _bloc.add(const DeafModeStarted());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _bloc.add(const DeafModeStopped());
    } else if (state == AppLifecycleState.resumed) {
      _bloc.add(const DeafModeStarted());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _bloc.add(const DeafModeStopped());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _bloc,
      child: BlocBuilder<DeafModeBloc, DeafModeState>(
        builder: (context, state) {
          return Scaffold(
            backgroundColor: AppTheme.deafModeBackground,
            body: SafeArea(
              child: _buildContent(context, state),
            ),
          );
        },
      ),
    );
  }

  Widget _buildContent(BuildContext context, DeafModeState state) {
    switch (state.status) {
      case DeafModeStatus.inactive:
      case DeafModeStatus.initializing:
        return _buildLoadingView();
      case DeafModeStatus.permissionRequired:
        return _buildPermissionView(context, state);
      case DeafModeStatus.error:
        return _buildErrorView(context, state);
      case DeafModeStatus.active:
        return _buildActiveView(context, state);
    }
  }

  Widget _buildLoadingView() {
    return Semantics(
      label: 'Initializing Deaf Mode. Please wait.',
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(
              color: AppTheme.deafModeAccent,
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

  Widget _buildPermissionView(BuildContext context, DeafModeState state) {
    return Semantics(
      label: 'Microphone and camera permissions required for Deaf Mode. Double tap anywhere to grant permissions.',
      child: GestureDetector(
        onDoubleTap: () {
          context.read<DeafModeBloc>().add(const DeafModePermissionRequested());
        },
        child: Container(
          width: double.infinity,
          height: double.infinity,
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.mic,
                size: 80,
                color: AppTheme.deafModeAccent,
              ),
              const SizedBox(height: 24),
              Text(
                'Permissions Required',
                style: AppTheme.headlineMedium.copyWith(
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'Deaf Mode needs microphone access for speech-to-text and camera access for sign language recognition.',
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
                    context.read<DeafModeBloc>().add(const DeafModePermissionRequested());
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.deafModeAccent,
                    foregroundColor: Colors.black,
                  ),
                  child: const Text(
                    'Grant Permissions',
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

  Widget _buildErrorView(BuildContext context, DeafModeState state) {
    return Semantics(
      label: 'Error: ${state.errorMessage}. Double tap to retry.',
      child: GestureDetector(
        onDoubleTap: () {
          context.read<DeafModeBloc>().add(const DeafModeStarted());
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
                    context.read<DeafModeBloc>().add(const DeafModeStarted());
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.deafModeAccent,
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

  Widget _buildActiveView(BuildContext context, DeafModeState state) {
    return Column(
      children: [
        // Mode indicator at top
        _buildModeIndicator(state),
        
        // Sound visualizer
        if (state.speechToTextEnabled)
          SoundVisualizer(soundLevel: state.soundLevel),
        
        // Main transcription display
        Expanded(
          flex: 2,
          child: TranscriptionDisplay(
            currentTranscription: state.currentTranscription,
            currentGesture: state.currentGesture,
          ),
        ),
        
        // Conversation history (scrollable)
        Expanded(
          flex: 3,
          child: ConversationHistory(
            history: state.conversationHistory,
            onClear: () {
              context.read<DeafModeBloc>().add(const DeafModeHistoryCleared());
            },
          ),
        ),
        
        // Controls at bottom
        DeafModeControls(
          speechToTextEnabled: state.speechToTextEnabled,
          signRecognitionEnabled: state.signRecognitionEnabled,
          signToSpeechEnabled: state.signToSpeechEnabled,
          aiEnhancementEnabled: state.aiEnhancementEnabled,
          onFeatureToggle: (feature) {
            context.read<DeafModeBloc>().add(DeafModeFeatureToggled(feature));
          },
        ),
      ],
    );
  }

  Widget _buildModeIndicator(DeafModeState state) {
    return Semantics(
      label: 'Deaf Mode active. '
             '${state.speechToTextEnabled ? "Speech to text on." : ""} '
             '${state.signRecognitionEnabled ? "Sign recognition on." : ""} '
             'Swipe left or right to switch to Blind Mode.',
      child: Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.hearing_disabled,
              color: AppTheme.deafModeAccent,
              size: 28,
            ),
            const SizedBox(width: 12),
            Text(
              'DEAF MODE',
              style: AppTheme.labelLarge.copyWith(
                color: AppTheme.deafModeAccent,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
            ),
            if (state.aiEnhancementEnabled) ...[
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.deafModeAccent.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'AI',
                  style: AppTheme.labelLarge.copyWith(
                    color: AppTheme.deafModeAccent,
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
}
