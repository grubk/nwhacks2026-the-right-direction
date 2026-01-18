import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/models/app_mode.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/app_mode_provider.dart';
import '../../blind_mode/presentation/blind_mode_screen.dart';
import '../../deaf_mode/presentation/deaf_mode_screen.dart';
import '../widgets/mode_switch_gesture_detector.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> with TickerProviderStateMixin {
  late AnimationController _transitionController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _transitionController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _transitionController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _transitionController.dispose();
    super.dispose();
  }

  Future<void> _handleModeSwitch() async {
    // Animate transition
    await _transitionController.forward();
    
    // Toggle mode
    await ref.read(appModeNotifierProvider.notifier).toggleMode();
    
    // Animate back
    await _transitionController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final currentMode = ref.watch(appModeNotifierProvider);
    final deviceCapabilities = ref.watch(deviceCapabilitiesProvider);

    return Semantics(
      label: 'The Right Direction - ${currentMode.displayName}',
      child: ModeSwitchGestureDetector(
        onModeSwitch: _handleModeSwitch,
        child: Scaffold(
          backgroundColor: currentMode == AppMode.deaf
              ? AppTheme.deafModeBackground
              : AppTheme.blindModeBackground,
          body: SafeArea(
            child: FadeTransition(
              opacity: _fadeAnimation.drive(Tween(begin: 1.0, end: 0.5)),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: currentMode == AppMode.deaf
                    ? const DeafModeScreen(key: ValueKey('deaf'))
                    : BlindModeScreen(
                        key: const ValueKey('blind'),
                        hasLidar: deviceCapabilities.hasLidar,
                      ),
              ),
            ),
          ),
          // Mode indicator at top
          floatingActionButtonLocation: FloatingActionButtonLocation.centerTop,
          floatingActionButton: _buildModeIndicator(currentMode),
        ),
      ),
    );
  }

  Widget _buildModeIndicator(AppMode mode) {
    return Semantics(
      label: '${mode.displayName} active. Swipe left or right anywhere to switch modes.',
      child: Container(
        margin: EdgeInsets.only(top: 8.h),
        padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.h),
        decoration: BoxDecoration(
          color: mode == AppMode.deaf
              ? AppTheme.deafModeAccent.withOpacity(0.2)
              : AppTheme.blindModeAccent.withOpacity(0.2),
          borderRadius: BorderRadius.circular(30.r),
          border: Border.all(
            color: mode == AppMode.deaf
                ? AppTheme.deafModeAccent
                : AppTheme.blindModeAccent,
            width: 2,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              mode == AppMode.deaf ? Icons.hearing_disabled : Icons.visibility_off,
              color: Colors.white,
              size: 24.sp,
              semanticLabel: mode.displayName,
            ),
            SizedBox(width: 12.w),
            Text(
              mode.displayName,
              style: TextStyle(
                color: Colors.white,
                fontSize: 18.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
