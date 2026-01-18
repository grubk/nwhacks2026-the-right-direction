import 'package:flutter/material.dart';
import '../bloc/app_mode_bloc.dart';

/// Gesture detector that captures horizontal swipes anywhere on screen
/// Used to toggle between Deaf Mode and Blind Mode
class ModeSwitchGestureDetector extends StatefulWidget {
  final Widget child;
  final void Function(SwipeDirection direction) onSwipe;
  final double swipeThreshold;
  final double swipeVelocityThreshold;

  const ModeSwitchGestureDetector({
    super.key,
    required this.child,
    required this.onSwipe,
    this.swipeThreshold = 50.0,
    this.swipeVelocityThreshold = 300.0,
  });

  @override
  State<ModeSwitchGestureDetector> createState() => _ModeSwitchGestureDetectorState();
}

class _ModeSwitchGestureDetectorState extends State<ModeSwitchGestureDetector> {
  double _startX = 0;
  double _startY = 0;
  DateTime? _startTime;
  bool _isSwiping = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragStart: _onDragStart,
      onHorizontalDragUpdate: _onDragUpdate,
      onHorizontalDragEnd: _onDragEnd,
      child: widget.child,
    );
  }

  void _onDragStart(DragStartDetails details) {
    _startX = details.globalPosition.dx;
    _startY = details.globalPosition.dy;
    _startTime = DateTime.now();
    _isSwiping = true;
  }

  void _onDragUpdate(DragUpdateDetails details) {
    if (!_isSwiping) return;

    // Check if the gesture is more horizontal than vertical
    final dx = (details.globalPosition.dx - _startX).abs();
    final dy = (details.globalPosition.dy - _startY).abs();

    if (dy > dx * 1.5) {
      // Too vertical, cancel swipe detection
      _isSwiping = false;
    }
  }

  void _onDragEnd(DragEndDetails details) {
    if (!_isSwiping || _startTime == null) {
      _resetSwipe();
      return;
    }

    final velocity = details.velocity.pixelsPerSecond.dx;
    final duration = DateTime.now().difference(_startTime!).inMilliseconds;
    
    // Check velocity threshold
    if (velocity.abs() > widget.swipeVelocityThreshold) {
      final direction = velocity > 0 ? SwipeDirection.right : SwipeDirection.left;
      widget.onSwipe(direction);
    }
    // Also trigger if distance threshold met (for slower, deliberate swipes)
    else if (details.primaryVelocity != null) {
      final distance = details.primaryVelocity! * duration / 1000;
      if (distance.abs() > widget.swipeThreshold) {
        final direction = distance > 0 ? SwipeDirection.right : SwipeDirection.left;
        widget.onSwipe(direction);
      }
    }

    _resetSwipe();
  }

  void _resetSwipe() {
    _startX = 0;
    _startY = 0;
    _startTime = null;
    _isSwiping = false;
  }
}
