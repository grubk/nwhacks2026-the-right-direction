import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/app_mode.dart';
import '../bloc/app_mode_bloc.dart';
import '../widgets/mode_switch_gesture_detector.dart';
import '../../../blind_mode/presentation/pages/blind_mode_page.dart';
import '../../../deaf_mode/presentation/pages/deaf_mode_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AppModeBloc, AppModeState>(
      builder: (context, state) {
        if (state.status == AppModeStatus.loading ||
            state.status == AppModeStatus.initial) {
          return const _LoadingScreen();
        }

        if (state.status == AppModeStatus.error) {
          return _ErrorScreen(message: state.errorMessage ?? 'Unknown error');
        }

        return ModeSwitchGestureDetector(
          onSwipe: (direction) {
            context.read<AppModeBloc>().add(AppModeSwipeDetected(direction));
          },
          child: Semantics(
            label: state.mode.announcement,
            liveRegion: true,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (child, animation) {
                return FadeTransition(
                  opacity: animation,
                  child: child,
                );
              },
              child: state.mode == AppMode.deaf
                  ? DeafModePage(key: const ValueKey('deaf'))
                  : BlindModePage(key: const ValueKey('blind')),
            ),
          ),
        );
      },
    );
  }
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      body: Center(
        child: Semantics(
          label: 'Loading The Right Direction app',
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(
                strokeWidth: 4,
                color: AppTheme.primaryDark,
              ),
              const SizedBox(height: 24),
              Text(
                'The Right Direction',
                style: AppTheme.headlineMedium.copyWith(
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Loading...',
                style: AppTheme.bodyLarge.copyWith(
                  color: Colors.white70,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorScreen extends StatelessWidget {
  final String message;

  const _ErrorScreen({required this.message});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      body: Center(
        child: Semantics(
          label: 'Error: $message. Double tap to retry.',
          child: GestureDetector(
            onDoubleTap: () {
              context.read<AppModeBloc>().add(const AppModeInitialized());
            },
            child: Container(
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
                    'Something went wrong',
                    style: AppTheme.headlineMedium.copyWith(
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    message,
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
                        context.read<AppModeBloc>().add(const AppModeInitialized());
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryDark,
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
        ),
      ),
    );
  }
}
