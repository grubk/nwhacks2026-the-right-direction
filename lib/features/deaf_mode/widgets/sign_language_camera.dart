import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/models/sign_language_gesture.dart';
import '../../../core/theme/app_theme.dart';

/// Camera widget for sign language recognition
class SignLanguageCamera extends StatefulWidget {
  final bool isActive;
  final Function(SignLanguageGesture)? onGestureDetected;

  const SignLanguageCamera({
    super.key,
    required this.isActive,
    this.onGestureDetected,
  });

  @override
  State<SignLanguageCamera> createState() => _SignLanguageCameraState();
}

class _SignLanguageCameraState extends State<SignLanguageCamera> {
  CameraController? _controller;
  bool _isCameraReady = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  @override
  void didUpdateWidget(SignLanguageCamera oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive != oldWidget.isActive) {
      if (widget.isActive) {
        _initializeCamera();
      } else {
        _disposeCamera();
      }
    }
  }

  @override
  void dispose() {
    _disposeCamera();
    super.dispose();
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() => _errorMessage = 'No camera available');
        return;
      }

      // Use front camera for sign language
      final frontCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      _controller = CameraController(
        frontCamera,
        ResolutionPreset.medium,
        enableAudio: false,
      );

      await _controller!.initialize();

      if (mounted) {
        setState(() => _isCameraReady = true);
      }
    } catch (e) {
      setState(() => _errorMessage = 'Failed to initialize camera');
    }
  }

  Future<void> _disposeCamera() async {
    await _controller?.dispose();
    _controller = null;
    if (mounted) {
      setState(() => _isCameraReady = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_errorMessage != null) {
      return _buildErrorState();
    }

    if (!_isCameraReady || _controller == null) {
      return _buildLoadingState();
    }

    return Semantics(
      label: widget.isActive
          ? 'Sign language camera active. Show your signs clearly.'
          : 'Sign language camera. Tap start to begin.',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20.r),
        child: Container(
          margin: EdgeInsets.all(16.w),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20.r),
            border: Border.all(
              color: widget.isActive
                  ? AppTheme.deafModeAccent
                  : Colors.white30,
              width: 3,
            ),
          ),
          child: Stack(
            children: [
              // Camera preview
              if (widget.isActive)
                ClipRRect(
                  borderRadius: BorderRadius.circular(17.r),
                  child: CameraPreview(_controller!),
                )
              else
                _buildInactiveState(),

              // Hand guide overlay
              if (widget.isActive) _buildHandGuide(),

              // Status indicator
              Positioned(
                top: 16.h,
                left: 16.w,
                child: _buildStatusIndicator(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Container(
      margin: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.black45,
        borderRadius: BorderRadius.circular(20.r),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              color: AppTheme.deafModeAccent,
            ),
            SizedBox(height: 16.h),
            Text(
              'Initializing camera...',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 16.sp,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Container(
      margin: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.black45,
        borderRadius: BorderRadius.circular(20.r),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 60.sp,
              color: AppTheme.errorColor,
            ),
            SizedBox(height: 16.h),
            Text(
              _errorMessage!,
              style: TextStyle(
                color: Colors.white,
                fontSize: 16.sp,
              ),
            ),
            SizedBox(height: 16.h),
            ElevatedButton(
              onPressed: () {
                setState(() => _errorMessage = null);
                _initializeCamera();
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInactiveState() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black45,
        borderRadius: BorderRadius.circular(17.r),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.sign_language,
              size: 80.sp,
              color: Colors.white30,
            ),
            SizedBox(height: 16.h),
            Text(
              'Sign Language Recognition',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 18.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              'Tap Start to begin',
              style: TextStyle(
                color: Colors.white38,
                fontSize: 14.sp,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHandGuide() {
    return Positioned.fill(
      child: CustomPaint(
        painter: HandGuidePainter(),
      ),
    );
  }

  Widget _buildStatusIndicator() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: widget.isActive
            ? Colors.green.withOpacity(0.8)
            : Colors.grey.withOpacity(0.8),
        borderRadius: BorderRadius.circular(20.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8.w,
            height: 8.w,
            decoration: BoxDecoration(
              color: widget.isActive ? Colors.greenAccent : Colors.grey,
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(width: 8.w),
          Text(
            widget.isActive ? 'Detecting' : 'Ready',
            style: TextStyle(
              color: Colors.white,
              fontSize: 12.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Painter to draw hand position guide overlay
class HandGuidePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppTheme.deafModeAccent.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    // Draw hand position guide rectangle
    final rect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(size.width / 2, size.height / 2),
        width: size.width * 0.6,
        height: size.height * 0.7,
      ),
      Radius.circular(20),
    );

    canvas.drawRRect(rect, paint);

    // Draw corner brackets
    final bracketPaint = Paint()
      ..color = AppTheme.deafModeAccent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    final bracketLength = size.width * 0.1;
    final left = size.width * 0.2;
    final right = size.width * 0.8;
    final top = size.height * 0.15;
    final bottom = size.height * 0.85;

    // Top-left bracket
    canvas.drawLine(Offset(left, top + bracketLength), Offset(left, top), bracketPaint);
    canvas.drawLine(Offset(left, top), Offset(left + bracketLength, top), bracketPaint);

    // Top-right bracket
    canvas.drawLine(Offset(right - bracketLength, top), Offset(right, top), bracketPaint);
    canvas.drawLine(Offset(right, top), Offset(right, top + bracketLength), bracketPaint);

    // Bottom-left bracket
    canvas.drawLine(Offset(left, bottom - bracketLength), Offset(left, bottom), bracketPaint);
    canvas.drawLine(Offset(left, bottom), Offset(left + bracketLength, bottom), bracketPaint);

    // Bottom-right bracket
    canvas.drawLine(Offset(right - bracketLength, bottom), Offset(right, bottom), bracketPaint);
    canvas.drawLine(Offset(right, bottom), Offset(right, bottom - bracketLength), bracketPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
