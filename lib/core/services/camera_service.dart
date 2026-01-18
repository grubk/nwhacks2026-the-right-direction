import 'dart:async';
import 'package:camera/camera.dart';

/// Detected object from camera analysis
class DetectedObject {
  final String label;
  final double confidence;
  final double distance; // Estimated distance in meters
  final ObjectDirection direction;
  final BoundingBox boundingBox;

  const DetectedObject({
    required this.label,
    required this.confidence,
    required this.distance,
    required this.direction,
    required this.boundingBox,
  });

  /// Proximity level for haptic feedback
  ProximityLevel get proximityLevel {
    if (distance < 1.0) return ProximityLevel.veryClose;
    if (distance < 1.5) return ProximityLevel.close;
    if (distance < 2.5) return ProximityLevel.medium;
    if (distance < 4.0) return ProximityLevel.far;
    return ProximityLevel.veryFar;
  }
}

enum ObjectDirection {
  left,
  center,
  right,
  unknown,
}

enum ProximityLevel {
  veryClose,  // < 1m - urgent warning (haptic)
  close,      // 1-1.5m - strong warning (haptic)
  medium,     // 1.5-2.5m - moderate warning (TTS only)
  far,        // 2.5-4m - light notification (TTS only)
  veryFar,    // > 4m - minimal/no feedback
}

class BoundingBox {
  final double left;
  final double top;
  final double right;
  final double bottom;

  const BoundingBox({
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
  });

  double get width => right - left;
  double get height => bottom - top;
  double get centerX => left + width / 2;
  double get centerY => top + height / 2;
}

/// Abstract camera service interface
/// Implementations provided per platform via method channels
abstract class CameraService {
  /// Initialize camera for object detection
  Future<void> initialize({
    CameraLensDirection direction = CameraLensDirection.back,
    ResolutionPreset resolution = ResolutionPreset.veryHigh,
  });

  /// Start streaming camera frames for analysis
  Stream<CameraImage> get frameStream;

  /// Get current camera state
  CameraState get state;

  /// Switch between front and back camera
  Future<void> switchCamera();

  /// Pause camera streaming
  Future<void> pause();

  /// Resume camera streaming
  Future<void> resume();

  /// Release camera resources
  Future<void> dispose();

  /// Check if camera is available
  Future<bool> isAvailable();

  /// Get camera preview widget
  CameraPreview? get preview;
}

enum CameraState {
  uninitialized,
  initializing,
  ready,
  streaming,
  paused,
  error,
  disposed,
}

/// Camera preview abstraction
abstract class CameraPreview {
  double get aspectRatio;
  dynamic get controller; // CameraController for Flutter camera package
}

/// Camera image frame for processing
class CameraImage {
  final List<Plane> planes;
  final int width;
  final int height;
  final ImageFormat format;
  final int rotation;
  final DateTime timestamp;

  const CameraImage({
    required this.planes,
    required this.width,
    required this.height,
    required this.format,
    required this.rotation,
    required this.timestamp,
  });
}

class Plane {
  final List<int> bytes;
  final int bytesPerRow;
  final int? bytesPerPixel;

  const Plane({
    required this.bytes,
    required this.bytesPerRow,
    this.bytesPerPixel,
  });
}

enum ImageFormat {
  yuv420,
  bgra8888,
  jpeg,
  nv21,
}

/// Implementation of CameraService using flutter camera package
class CameraServiceImpl implements CameraService {
  CameraController? _controller;
  final _frameController = StreamController<CameraImage>.broadcast();
  CameraState _state = CameraState.uninitialized;
  List<CameraDescription>? _cameras;

  @override
  CameraState get state => _state;

  @override
  Stream<CameraImage> get frameStream => _frameController.stream;

  @override
  CameraPreview? get preview {
    if (_controller == null || !_controller!.value.isInitialized) return null;
    return _CameraPreviewImpl(_controller!);
  }

  @override
  Future<bool> isAvailable() async {
    try {
      _cameras = await availableCameras();
      return _cameras != null && _cameras!.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<void> initialize({
    CameraLensDirection direction = CameraLensDirection.back,
    ResolutionPreset resolution = ResolutionPreset.veryHigh,
  }) async {
    _state = CameraState.initializing;
    
    try {
      _cameras ??= await availableCameras();
      
      if (_cameras == null || _cameras!.isEmpty) {
        _state = CameraState.error;
        throw CameraException('no_camera', 'No cameras available');
      }

      final camera = _cameras!.firstWhere(
        (c) => c.lensDirection == direction,
        orElse: () => _cameras!.first,
      );

      _controller = CameraController(
        camera,
        resolution,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );

      await _controller!.initialize();
      
      _state = CameraState.ready;
    } catch (e) {
      _state = CameraState.error;
      rethrow;
    }
  }

  int _streamFrameCount = 0;

  Future<void> startImageStream() async {
    if (_controller == null || !_controller!.value.isInitialized) {
      print('[Camera DEBUG] Cannot start image stream - controller not initialized');
      return;
    }
    
    print('[Camera DEBUG] Starting image stream...');
    _state = CameraState.streaming;
    _streamFrameCount = 0;
    
    await _controller!.startImageStream((image) {
      _streamFrameCount++;
      
      // Log every 60th frame to confirm stream is working
      if (_streamFrameCount % 60 == 0) {
        print('[Camera DEBUG] Frame #$_streamFrameCount received (${image.width}x${image.height})');
      }
      
      final cameraImage = CameraImage(
        planes: image.planes.map((p) => Plane(
          bytes: p.bytes,
          bytesPerRow: p.bytesPerRow,
          bytesPerPixel: p.bytesPerPixel,
        )).toList(),
        width: image.width,
        height: image.height,
        format: _convertFormat(image.format.group),
        rotation: _controller!.description.sensorOrientation,
        timestamp: DateTime.now(),
      );
      _frameController.add(cameraImage);
    });
    
    print('[Camera DEBUG] Image stream started successfully');
  }

  ImageFormat _convertFormat(ImageFormatGroup group) {
    switch (group) {
      case ImageFormatGroup.yuv420:
        return ImageFormat.yuv420;
      case ImageFormatGroup.bgra8888:
        return ImageFormat.bgra8888;
      case ImageFormatGroup.jpeg:
        return ImageFormat.jpeg;
      case ImageFormatGroup.nv21:
        return ImageFormat.nv21;
      default:
        return ImageFormat.yuv420;
    }
  }

  @override
  Future<void> switchCamera() async {
    if (_cameras == null || _cameras!.length < 2) return;
    
    final currentDirection = _controller?.description.lensDirection;
    final newDirection = currentDirection == CameraLensDirection.back
        ? CameraLensDirection.front
        : CameraLensDirection.back;
    
    await dispose();
    await initialize(direction: newDirection);
  }

  @override
  Future<void> pause() async {
    if (_controller?.value.isStreamingImages ?? false) {
      await _controller?.stopImageStream();
    }
    _state = CameraState.paused;
  }

  @override
  Future<void> resume() async {
    if (_state == CameraState.paused) {
      await startImageStream();
    }
  }

  @override
  Future<void> dispose() async {
    await _controller?.dispose();
    _controller = null;
    _state = CameraState.disposed;
  }
}

class _CameraPreviewImpl implements CameraPreview {
  final CameraController controller;

  _CameraPreviewImpl(this.controller);

  @override
  double get aspectRatio => controller.value.aspectRatio;
}
