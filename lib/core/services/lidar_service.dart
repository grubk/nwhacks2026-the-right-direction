import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';

/// LiDAR service for iOS devices with LiDAR capability
/// Provides precise depth sensing for blind mode navigation
abstract class LidarService {
  /// Initialize LiDAR sensor
  Future<void> initialize();
  
  /// Check if device supports LiDAR
  Future<bool> isLidarAvailable();
  
  /// Check if LiDAR is currently active
  bool get isActive;
  
  /// Start depth scanning
  Future<void> startScanning();
  
  /// Stop depth scanning
  Future<void> stopScanning();
  
  /// Stream of depth data
  Stream<DepthData> get depthStream;
  
  /// Get single depth measurement at point
  Future<double?> getDepthAtPoint(double x, double y);
  
  /// Get closest object distance
  Future<double?> getClosestObjectDistance();
  
  /// Dispose LiDAR resources
  Future<void> dispose();
}

/// Depth data from LiDAR sensor
class DepthData {
  final List<DepthPoint> points;
  final int width;
  final int height;
  final double minDepth;
  final double maxDepth;
  final DateTime timestamp;

  const DepthData({
    required this.points,
    required this.width,
    required this.height,
    required this.minDepth,
    required this.maxDepth,
    required this.timestamp,
  });

  /// Get closest point in a region
  DepthPoint? getClosestInRegion(double x1, double y1, double x2, double y2) {
    DepthPoint? closest;
    double minDist = double.infinity;

    for (final point in points) {
      if (point.x >= x1 && point.x <= x2 && 
          point.y >= y1 && point.y <= y2 &&
          point.depth < minDist) {
        minDist = point.depth;
        closest = point;
      }
    }

    return closest;
  }

  /// Get average depth in a region
  double? getAverageDepthInRegion(double x1, double y1, double x2, double y2) {
    final pointsInRegion = points.where((p) =>
      p.x >= x1 && p.x <= x2 && p.y >= y1 && p.y <= y2
    ).toList();

    if (pointsInRegion.isEmpty) return null;

    final sum = pointsInRegion.fold<double>(0, (acc, p) => acc + p.depth);
    return sum / pointsInRegion.length;
  }

  /// Get depth zones for navigation feedback
  Map<DepthZone, List<DepthPoint>> getDepthZones() {
    final zones = <DepthZone, List<DepthPoint>>{
      DepthZone.immediate: [],
      DepthZone.near: [],
      DepthZone.medium: [],
      DepthZone.far: [],
    };

    for (final point in points) {
      if (point.depth < 0.5) {
        zones[DepthZone.immediate]!.add(point);
      } else if (point.depth < 1.0) {
        zones[DepthZone.near]!.add(point);
      } else if (point.depth < 2.0) {
        zones[DepthZone.medium]!.add(point);
      } else {
        zones[DepthZone.far]!.add(point);
      }
    }

    return zones;
  }
}

class DepthPoint {
  final double x; // Normalized 0-1
  final double y; // Normalized 0-1
  final double depth; // Meters
  final double confidence;

  const DepthPoint({
    required this.x,
    required this.y,
    required this.depth,
    this.confidence = 1.0,
  });

  /// Get direction of this point
  PointDirection get direction {
    if (x < 0.33) return PointDirection.left;
    if (x > 0.66) return PointDirection.right;
    return PointDirection.center;
  }
}

enum DepthZone {
  immediate, // < 0.5m
  near,      // 0.5-1m
  medium,    // 1-2m
  far,       // > 2m
}

enum PointDirection {
  left,
  center,
  right,
}

class LidarServiceImpl implements LidarService {
  static const _channel = MethodChannel('com.therightdirection/lidar');
  static const _eventChannel = EventChannel('com.therightdirection/lidar_events');
  
  final _depthController = StreamController<DepthData>.broadcast();
  StreamSubscription? _eventSubscription;
  bool _isActive = false;
  bool _isAvailable = false;

  @override
  bool get isActive => _isActive;

  @override
  Stream<DepthData> get depthStream => _depthController.stream;

  @override
  Future<void> initialize() async {
    if (!Platform.isIOS) {
      _isAvailable = false;
      return;
    }

    try {
      _isAvailable = await _channel.invokeMethod<bool>('isLidarAvailable') ?? false;
      
      if (_isAvailable) {
        await _channel.invokeMethod('initializeLidar');
        _setupEventChannel();
      }
    } catch (e) {
      _isAvailable = false;
    }
  }

  void _setupEventChannel() {
    _eventSubscription = _eventChannel
        .receiveBroadcastStream()
        .listen(_handleDepthEvent, onError: _handleError);
  }

  void _handleDepthEvent(dynamic event) {
    if (event is! Map) return;

    try {
      final width = event['width'] as int;
      final height = event['height'] as int;
      final depthValues = (event['depths'] as List).cast<double>();
      final confidences = (event['confidences'] as List?)?.cast<double>();

      final points = <DepthPoint>[];
      double minDepth = double.infinity;
      double maxDepth = 0;

      for (int i = 0; i < depthValues.length; i++) {
        final x = (i % width) / width;
        final y = (i ~/ width) / height;
        final depth = depthValues[i];
        final confidence = confidences?[i] ?? 1.0;

        if (depth > 0 && confidence > 0.5) {
          points.add(DepthPoint(
            x: x,
            y: y,
            depth: depth,
            confidence: confidence,
          ));

          if (depth < minDepth) minDepth = depth;
          if (depth > maxDepth) maxDepth = depth;
        }
      }

      _depthController.add(DepthData(
        points: points,
        width: width,
        height: height,
        minDepth: minDepth,
        maxDepth: maxDepth,
        timestamp: DateTime.now(),
      ));
    } catch (e) {
      // Invalid event format
    }
  }

  void _handleError(dynamic error) {
    _isActive = false;
  }

  @override
  Future<bool> isLidarAvailable() async {
    if (!Platform.isIOS) return false;
    
    try {
      return await _channel.invokeMethod<bool>('isLidarAvailable') ?? false;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<void> startScanning() async {
    if (!_isAvailable) return;

    try {
      await _channel.invokeMethod('startScanning');
      _isActive = true;
    } catch (e) {
      _isActive = false;
    }
  }

  @override
  Future<void> stopScanning() async {
    if (!_isActive) return;

    try {
      await _channel.invokeMethod('stopScanning');
      _isActive = false;
    } catch (e) {
      // Ignore stop errors
    }
  }

  @override
  Future<double?> getDepthAtPoint(double x, double y) async {
    if (!_isAvailable || !_isActive) return null;

    try {
      return await _channel.invokeMethod<double>('getDepthAtPoint', {
        'x': x,
        'y': y,
      });
    } catch (e) {
      return null;
    }
  }

  @override
  Future<double?> getClosestObjectDistance() async {
    if (!_isAvailable || !_isActive) return null;

    try {
      return await _channel.invokeMethod<double>('getClosestDistance');
    } catch (e) {
      return null;
    }
  }

  @override
  Future<void> dispose() async {
    await stopScanning();
    await _eventSubscription?.cancel();
    await _depthController.close();
  }
}
