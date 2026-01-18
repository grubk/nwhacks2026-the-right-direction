import 'dart:async';

import '../../../../core/services/camera_service.dart';
import '../../../../core/services/ml_service.dart';
import '../../../../core/services/lidar_service.dart';
import '../../domain/entities/navigation_alert.dart';
import '../../domain/repositories/object_detection_repository.dart';

class ObjectDetectionRepositoryImpl implements ObjectDetectionRepository {
  final CameraService cameraService;
  final MlService mlService;
  final LidarService lidarService;

  final _objectController = StreamController<List<DetectedObject>>.broadcast();
  final _alertController = StreamController<NavigationAlert>.broadcast();

  StreamSubscription? _frameSubscription;
  StreamSubscription? _lidarSubscription;

  bool _isDetecting = false;
  bool _isLidarActive = false;
  bool _ttsEnabled = true;
  
  // Throttle detection to manage performance
  // Lower frame rate (500ms = 2 FPS) allows higher resolution processing
  DateTime? _lastDetectionTime;
  static const _detectionInterval = Duration(milliseconds: 500);

  ObjectDetectionRepositoryImpl({
    required this.cameraService,
    required this.mlService,
    required this.lidarService,
  });

  @override
  bool get isDetecting => _isDetecting;

  @override
  bool get isLidarActive => _isLidarActive;

  @override
  Stream<List<DetectedObject>> get objectStream => _objectController.stream;

  @override
  Stream<NavigationAlert> get alertStream => _alertController.stream;

  @override
  Future<void> startDetection() async {
    if (_isDetecting) return;

    print('[BlindMode DEBUG] Starting object detection...');

    // Initialize services
    try {
      await mlService.initialize();
      print('[BlindMode DEBUG] ML Service initialized: ${mlService.isInitialized}');
    } catch (e) {
      print('[BlindMode DEBUG] ML Service initialization FAILED: $e');
    }
    
    try {
      await cameraService.initialize();
      print('[BlindMode DEBUG] Camera Service initialized: ${cameraService.state}');
    } catch (e) {
      print('[BlindMode DEBUG] Camera Service initialization FAILED: $e');
    }

    // Check for LiDAR availability (iOS Pro devices)
    final lidarAvailable = await lidarService.isLidarAvailable();
    print('[BlindMode DEBUG] LiDAR available: $lidarAvailable');
    if (lidarAvailable) {
      await lidarService.initialize();
      await lidarService.startScanning();
      _isLidarActive = true;
      _setupLidarSubscription();
    }

    // Start camera streaming
    try {
      final cameraImpl = cameraService as CameraServiceImpl;
      await cameraImpl.startImageStream();
      print('[BlindMode DEBUG] Camera image stream started');
    } catch (e) {
      print('[BlindMode DEBUG] Camera image stream FAILED: $e');
    }

    // Subscribe to camera frames
    _frameSubscription = cameraService.frameStream.listen(
      _processFrame,
      onError: (e) => print('[BlindMode DEBUG] Frame stream error: $e'),
    );
    print('[BlindMode DEBUG] Subscribed to frame stream');

    _isDetecting = true;
    print('[BlindMode DEBUG] Detection started successfully');
  }

  void _setupLidarSubscription() {
    _lidarSubscription = lidarService.depthStream.listen((depthData) {
      // Use LiDAR data to enhance distance estimation
      _processLidarData(depthData);
    });
  }

  int _frameCount = 0;
  
  Future<void> _processFrame(CameraImage frame) async {
    _frameCount++;
    
    // Log every 30th frame to avoid log spam
    final shouldLog = _frameCount % 30 == 0;
    
    if (shouldLog) {
      print('[BlindMode DEBUG] Processing frame #$_frameCount (${frame.width}x${frame.height})');
    }
    
    // Throttle detection
    final now = DateTime.now();
    if (_lastDetectionTime != null &&
        now.difference(_lastDetectionTime!) < _detectionInterval) {
      return;
    }
    _lastDetectionTime = now;

    try {
      // Run object detection
      final objects = await mlService.detectObjects(frame);
      
      if (shouldLog) {
        print('[BlindMode DEBUG] Detection result: ${objects.length} objects found');
      }
      
      if (objects.isEmpty) {
        _objectController.add([]);
        _emitClearAlert();
        return;
      }

      // Log detected objects with distances
      print('[BlindMode DEBUG] Objects detected:');
      for (final obj in objects) {
        print('  - ${obj.label}: ${obj.distance.toStringAsFixed(2)}m (${obj.direction.name}, conf: ${(obj.confidence * 100).toStringAsFixed(1)}%)');
      }

      _objectController.add(objects);
      
      // Generate navigation alert
      final alert = _generateNavigationAlert(objects);
      print('[BlindMode DEBUG] Alert generated: level=${alert.level.name}, closest=${alert.closestObject?.label ?? "none"}');
      _alertController.add(alert);
    } catch (e, stackTrace) {
      // Log detection errors for debugging
      print('[BlindMode DEBUG] Detection error: $e');
      print('[BlindMode DEBUG] Stack trace: $stackTrace');
    }
  }

  void _processLidarData(DepthData depthData) {
    // LiDAR provides more accurate depth information
    // Use it to enhance object distance estimation
    
    final zones = depthData.getDepthZones();
    
    // Check for immediate obstacles
    if (zones[DepthZone.immediate]!.isNotEmpty) {
      final closestPoint = zones[DepthZone.immediate]!
          .reduce((a, b) => a.depth < b.depth ? a : b);
      
      // Create synthetic alert for LiDAR-detected obstacles
      final alert = NavigationAlert(
        objects: [],
        closestObject: DetectedObject(
          label: 'obstacle',
          confidence: closestPoint.confidence,
          distance: closestPoint.depth,
          direction: _pointDirectionToObjectDirection(closestPoint.direction),
          boundingBox: const BoundingBox(left: 0.4, top: 0.4, right: 0.6, bottom: 0.6),
        ),
        level: NavigationAlertLevel.critical,
        spokenGuidance: _generateLidarGuidance(closestPoint),
        timestamp: DateTime.now(),
      );
      
      _alertController.add(alert);
    }
  }

  ObjectDirection _pointDirectionToObjectDirection(PointDirection direction) {
    switch (direction) {
      case PointDirection.left:
        return ObjectDirection.left;
      case PointDirection.right:
        return ObjectDirection.right;
      case PointDirection.center:
        return ObjectDirection.center;
    }
  }

  String _generateLidarGuidance(DepthPoint point) {
    final distance = point.depth.toStringAsFixed(1);
    String direction;
    
    switch (point.direction) {
      case PointDirection.left:
        direction = 'on your left';
        break;
      case PointDirection.right:
        direction = 'on your right';
        break;
      case PointDirection.center:
        direction = 'directly ahead';
        break;
    }
    
    // LiDAR detects depth but not object type, so use "obstacle"
    return 'obstacle detected $distance meters $direction';
  }

  NavigationAlert _generateNavigationAlert(List<DetectedObject> objects) {
    // Find closest object
    DetectedObject? closest;
    for (final obj in objects) {
      if (closest == null || obj.distance < closest.distance) {
        closest = obj;
      }
    }

    // Determine alert level - adjusted thresholds for real-world distances
    // Only trigger alerts for genuinely close objects to reduce notification overload
    NavigationAlertLevel level;
    if (closest == null) {
      level = NavigationAlertLevel.clear;
    } else if (closest.distance < 1.0) {
      level = NavigationAlertLevel.critical;  // Very close - immediate danger
    } else if (closest.distance < 1.5) {
      level = NavigationAlertLevel.high;      // Close - needs attention
    } else if (closest.distance < 2.5) {
      level = NavigationAlertLevel.moderate;  // Approaching
    } else if (closest.distance < 4.0) {
      level = NavigationAlertLevel.low;       // Detected but not urgent
    } else {
      level = NavigationAlertLevel.clear;     // Far enough - no alert needed
    }

    // Generate spoken guidance
    final guidance = _generateSpokenGuidance(objects, closest, level);

    return NavigationAlert(
      objects: objects,
      closestObject: closest,
      level: level,
      spokenGuidance: guidance,
      timestamp: DateTime.now(),
    );
  }

  String _generateSpokenGuidance(
    List<DetectedObject> objects,
    DetectedObject? closest,
    NavigationAlertLevel level,
  ) {
    if (closest == null || level == NavigationAlertLevel.clear) {
      return 'Path clear';
    }

    final distance = closest.distance.toStringAsFixed(1);
    String direction;
    String directionForDetected;

    switch (closest.direction) {
      case ObjectDirection.left:
        direction = 'on your left';
        directionForDetected = 'to your left';
        break;
      case ObjectDirection.right:
        direction = 'on your right';
        directionForDetected = 'to your right';
        break;
      case ObjectDirection.center:
        direction = 'ahead';
        directionForDetected = 'ahead';
        break;
      case ObjectDirection.unknown:
        direction = 'nearby';
        directionForDetected = 'nearby';
        break;
    }

    // Determine if the object has a known label or is generic
    // ML Kit provides labels like "person", "car", etc. when it can identify the object
    // Generic labels "object" or "obstacle" are used when the type is unknown
    final label = closest.label.toLowerCase().trim();
    final isKnownObject = label.isNotEmpty && 
                          label != 'object' && 
                          label != 'obstacle' && 
                          label != 'unknown';
    
    // Use the actual object name if known, otherwise say "obstacle"
    final objectName = isKnownObject ? closest.label : 'obstacle';

    // Format the guidance based on urgency
    if (level == NavigationAlertLevel.critical) {
      // Critical: Very close, urgent warning
      return 'Stop! $objectName $direction';
    } else if (level == NavigationAlertLevel.high) {
      // High: Close, needs attention with distance info
      return 'Caution: $objectName $distance meters $direction';
    } else {
      // Low/Moderate: Standard detection announcement
      // Format: "{object name} detected ahead" or "obstacle detected ahead"
      return '$objectName detected $directionForDetected';
    }
  }

  void _emitClearAlert() {
    _alertController.add(NavigationAlert(
      objects: [],
      closestObject: null,
      level: NavigationAlertLevel.clear,
      spokenGuidance: '',
      timestamp: DateTime.now(),
    ));
  }

  @override
  Future<void> stopDetection() async {
    _isDetecting = false;
    
    await _frameSubscription?.cancel();
    await _lidarSubscription?.cancel();
    
    await cameraService.pause();
    await lidarService.stopScanning();
    
    _isLidarActive = false;
  }

  @override
  Future<void> setLidarEnabled(bool enabled) async {
    if (enabled && !_isLidarActive) {
      final available = await lidarService.isLidarAvailable();
      if (available) {
        await lidarService.startScanning();
        _isLidarActive = true;
        _setupLidarSubscription();
      }
    } else if (!enabled && _isLidarActive) {
      await lidarService.stopScanning();
      await _lidarSubscription?.cancel();
      _isLidarActive = false;
    }
  }

  @override
  Future<void> setTtsEnabled(bool enabled) async {
    _ttsEnabled = enabled;
  }

  @override
  Future<void> dispose() async {
    await stopDetection();
    await _objectController.close();
    await _alertController.close();
  }
}
