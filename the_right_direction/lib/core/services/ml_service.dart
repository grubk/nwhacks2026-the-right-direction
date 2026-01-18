import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/services.dart';
import 'package:google_mlkit_object_detection/google_mlkit_object_detection.dart' as mlkit;

import 'camera_service.dart';

/// ML Service abstraction for on-device inference
/// Handles object detection, hand landmark detection, and sign language recognition
abstract class MlService {
  /// Initialize ML models
  Future<void> initialize();
  
  /// Check if models are loaded
  bool get isInitialized;
  
  /// Run object detection on camera frame
  Future<List<DetectedObject>> detectObjects(CameraImage image);
  
  /// Run hand landmark detection for sign language
  Future<HandLandmarks?> detectHandLandmarks(CameraImage image);
  
  /// Recognize sign language gesture from landmarks
  Future<SignLanguageResult?> recognizeSign(HandLandmarks landmarks);
  
  /// Estimate distance of detected object (based on bounding box size)
  double estimateDistance(DetectedObject object, int imageWidth, int imageHeight);
  
  /// Dispose ML resources
  Future<void> dispose();
}

/// Hand landmark detection result
class HandLandmarks {
  final List<Landmark> landmarks;
  final double confidence;
  final HandType handType;

  const HandLandmarks({
    required this.landmarks,
    required this.confidence,
    required this.handType,
  });
}

class Landmark {
  final double x;
  final double y;
  final double z;
  final double visibility;

  const Landmark({
    required this.x,
    required this.y,
    required this.z,
    this.visibility = 1.0,
  });
}

enum HandType {
  left,
  right,
  unknown,
}

/// Sign language recognition result
class SignLanguageResult {
  final String gesture;
  final String meaning;
  final double confidence;
  final SignLanguageType type;

  const SignLanguageResult({
    required this.gesture,
    required this.meaning,
    required this.confidence,
    required this.type,
  });
}

enum SignLanguageType {
  asl, // American Sign Language
  bsl, // British Sign Language
  custom,
}

class MlServiceImpl implements MlService {
  static const _channel = MethodChannel('com.therightdirection/ml');
  
  mlkit.ObjectDetector? _mlKitObjectDetector;
  
  bool _isInitialized = false;
  
  // Model labels - not needed with ML Kit as it provides labels
  List<String> _objectLabels = [];
  List<String> _signLabels = [];

  // Object size reference for distance estimation (in meters)
  static const Map<String, double> _objectReferenceHeights = {
    'person': 1.7,
    'car': 1.5,
    'bicycle': 1.0,
    'dog': 0.5,
    'cat': 0.3,
    'chair': 0.8,
    'bottle': 0.25,
    'tv': 0.6,
    'laptop': 0.3,
    'cell phone': 0.15,
    'book': 0.25,
    'cup': 0.12,
    'door': 2.0,
    'table': 0.75,
    'couch': 0.9,
    'bed': 0.6,
    'toilet': 0.4,
    'sink': 0.6,
    'refrigerator': 1.7,
    'stop sign': 0.75,
    'fire hydrant': 0.5,
    'bench': 0.45,
    'bird': 0.2,
    'horse': 1.6,
    'sheep': 0.7,
    'cow': 1.4,
    'elephant': 3.0,
    'bear': 1.5,
    'zebra': 1.4,
    'giraffe': 5.5,
    'backpack': 0.5,
    'umbrella': 1.0,
    'handbag': 0.3,
    'tie': 0.5,
    'suitcase': 0.7,
    'sports ball': 0.22,
    'kite': 0.8,
    'tennis racket': 0.7,
    'skateboard': 0.1,
    'surfboard': 2.0,
    'wine glass': 0.2,
    'fork': 0.2,
    'knife': 0.25,
    'spoon': 0.18,
    'bowl': 0.1,
    'banana': 0.2,
    'apple': 0.08,
    'sandwich': 0.1,
    'orange': 0.08,
    'broccoli': 0.15,
    'carrot': 0.2,
    'pizza': 0.35,
    'cake': 0.15,
    'potted plant': 0.5,
    'mouse': 0.05,
    'keyboard': 0.45,
    'clock': 0.3,
    'vase': 0.3,
    'scissors': 0.2,
    'toothbrush': 0.2,
    'hair drier': 0.25,
  };

  @override
  bool get isInitialized => _isInitialized;

  @override
  Future<void> initialize() async {
    if (_isInitialized) return;

    print('[ML DEBUG] Initializing ML Service with Google ML Kit...');

    try {
      // Configure ML Kit Object Detector with base model (no download needed)
      final options = mlkit.ObjectDetectorOptions(
        mode: mlkit.DetectionMode.stream,
        classifyObjects: true,
        multipleObjects: true,
      );
      
      _mlKitObjectDetector = mlkit.ObjectDetector(options: options);
      print('[ML DEBUG] Google ML Kit Object Detector created successfully');

      _isInitialized = true;
      print('[ML DEBUG] ML Service initialization complete');
    } catch (e, stackTrace) {
      print('[ML DEBUG] ML Kit initialization failed: $e');
      print('[ML DEBUG] Stack trace: $stackTrace');
      _isInitialized = false;
    }
  }

  Future<void> _initializePlatformSpecific() async {
    // Not needed with ML Kit - keeping for interface compatibility
    print('[ML DEBUG] Platform-specific initialization not needed with ML Kit');
  }

  Future<List<String>> _loadLabels(String assetPath) async {
    try {
      final content = await rootBundle.loadString(assetPath);
      return content.split('\n').where((s) => s.isNotEmpty).toList();
    } catch (e) {
      return [];
    }
  }

  @override
  Future<List<DetectedObject>> detectObjects(CameraImage image) async {
    if (!_isInitialized || _mlKitObjectDetector == null) {
      print('[ML DEBUG] detectObjects called but not initialized (initialized=$_isInitialized, detector=${_mlKitObjectDetector != null})');
      return [];
    }

    try {
      // Convert CameraImage to InputImage for ML Kit
      final inputImage = _convertToInputImage(image);
      if (inputImage == null) {
        print('[ML DEBUG] Failed to convert camera image to InputImage');
        return [];
      }

      // Run ML Kit object detection
      final detectedObjects = await _mlKitObjectDetector!.processImage(inputImage);
      
      // Convert ML Kit results to our DetectedObject format
      final results = <DetectedObject>[];
      
      if (detectedObjects.isNotEmpty) {
        print('[ML DEBUG] ML Kit detected ${detectedObjects.length} objects');
        
        for (final obj in detectedObjects) {
          // Get the best label
          String label = 'object';
          double confidence = 0.5;
          
          if (obj.labels.isNotEmpty) {
            final bestLabel = obj.labels.reduce((a, b) => 
              a.confidence > b.confidence ? a : b);
            label = bestLabel.text.toLowerCase();
            confidence = bestLabel.confidence;
          }

          // Skip low confidence detections
          if (confidence < 0.3) continue;

          // Convert bounding box (ML Kit uses pixel coordinates)
          final rect = obj.boundingBox;
          final boundingBox = BoundingBox(
            left: rect.left / image.width,
            top: rect.top / image.height,
            right: rect.right / image.width,
            bottom: rect.bottom / image.height,
          );

          // Estimate distance based on bounding box
          final distance = _estimateDistanceFromBox(
            label,
            boundingBox,
            image.width,
            image.height,
          );

          // Determine direction
          final direction = _determineDirection(boundingBox);

          results.add(DetectedObject(
            label: label,
            confidence: confidence,
            distance: distance,
            direction: direction,
            boundingBox: boundingBox,
          ));
        }
      }
      
      // If ML Kit didn't detect anything, use fallback obstacle detection
      // This analyzes the image for potential obstacles (walls, large surfaces)
      if (results.isEmpty) {
        final fallbackResults = _detectObstaclesFallback(image);
        results.addAll(fallbackResults);
      }

      return results;
    } catch (e, stackTrace) {
      print('[ML DEBUG] Object detection error: $e');
      print('[ML DEBUG] Stack trace: $stackTrace');
      return [];
    }
  }

  /// Fallback obstacle detection using image analysis
  /// Analyzes the center region of the camera frame for potential obstacles
  /// based on luminance variance and edge density
  List<DetectedObject> _detectObstaclesFallback(CameraImage image) {
    try {
      if (image.planes.isEmpty) return [];
      
      // Get Y plane (luminance) from YUV image
      final yPlane = image.planes.first.bytes;
      final width = image.width;
      final height = image.height;
      
      // Analyze center region (where obstacles directly ahead would be)
      final centerStartX = (width * 0.25).toInt();
      final centerEndX = (width * 0.75).toInt();
      final centerStartY = (height * 0.3).toInt();
      final centerEndY = (height * 0.7).toInt();
      
      // Also analyze left, right, and center thirds
      final leftThirdEnd = (width * 0.33).toInt();
      final rightThirdStart = (width * 0.67).toInt();
      
      // Calculate average luminance and variance for different regions
      final centerStats = _calculateRegionStats(
        yPlane, width, height,
        centerStartX, centerStartY, centerEndX, centerEndY,
      );
      
      final leftStats = _calculateRegionStats(
        yPlane, width, height,
        0, centerStartY, leftThirdEnd, centerEndY,
      );
      
      final rightStats = _calculateRegionStats(
        yPlane, width, height,
        rightThirdStart, centerStartY, width, centerEndY,
      );
      
      final results = <DetectedObject>[];
      
      // Detect obstacles based on luminance patterns
      // Lower variance often indicates a flat surface (wall) nearby
      // Very dark center often indicates something blocking the view
      
      // Check center for obstacles
      final centerObstacle = _analyzeRegionForObstacle(
        centerStats, 
        ObjectDirection.center,
        'obstacle',
      );
      if (centerObstacle != null) {
        results.add(centerObstacle);
      }
      
      // Check left region
      final leftObstacle = _analyzeRegionForObstacle(
        leftStats,
        ObjectDirection.left,
        'obstacle',
      );
      if (leftObstacle != null) {
        results.add(leftObstacle);
      }
      
      // Check right region
      final rightObstacle = _analyzeRegionForObstacle(
        rightStats,
        ObjectDirection.right,
        'obstacle',
      );
      if (rightObstacle != null) {
        results.add(rightObstacle);
      }
      
      if (results.isNotEmpty) {
        print('[ML DEBUG] Fallback detection found ${results.length} obstacle(s)');
      }
      
      return results;
    } catch (e) {
      print('[ML DEBUG] Fallback detection error: $e');
      return [];
    }
  }
  
  /// Calculate luminance statistics for a region
  Map<String, double> _calculateRegionStats(
    List<int> yPlane,
    int imageWidth,
    int imageHeight,
    int startX,
    int startY,
    int endX,
    int endY,
  ) {
    double sum = 0;
    double sumSquared = 0;
    int count = 0;
    int edgeCount = 0;
    
    // Sample every 4th pixel for performance
    for (int y = startY; y < endY; y += 4) {
      for (int x = startX; x < endX; x += 4) {
        final index = y * imageWidth + x;
        if (index >= 0 && index < yPlane.length) {
          final value = yPlane[index].toDouble();
          sum += value;
          sumSquared += value * value;
          count++;
          
          // Simple edge detection - check horizontal gradient
          if (x + 4 < endX) {
            final nextIndex = y * imageWidth + x + 4;
            if (nextIndex < yPlane.length) {
              final diff = (yPlane[nextIndex] - yPlane[index]).abs();
              if (diff > 30) edgeCount++;
            }
          }
        }
      }
    }
    
    if (count == 0) {
      return {'mean': 128, 'variance': 1000, 'edgeDensity': 0};
    }
    
    final mean = sum / count;
    final variance = (sumSquared / count) - (mean * mean);
    final edgeDensity = edgeCount / count;
    
    return {
      'mean': mean,
      'variance': variance,
      'edgeDensity': edgeDensity,
    };
  }
  
  /// Analyze region statistics to determine if there's an obstacle
  DetectedObject? _analyzeRegionForObstacle(
    Map<String, double> stats,
    ObjectDirection direction,
    String label,
  ) {
    final mean = stats['mean']!;
    final variance = stats['variance']!;
    final edgeDensity = stats['edgeDensity']!;
    
    // Heuristics for obstacle detection:
    // 1. Very low variance (< 500) suggests a flat, uniform surface (wall) close by
    // 2. Very dark (mean < 50) suggests something blocking light
    // 3. Very high edge density with low variance suggests textured wall nearby
    
    double distance = 10.0; // Default far away
    double confidence = 0.0;
    
    // Low variance indicates uniform surface (likely wall or large object)
    if (variance < 300) {
      // Very close - very uniform surface
      distance = 0.3;
      confidence = 0.8;
    } else if (variance < 800) {
      // Close - somewhat uniform
      distance = 0.7;
      confidence = 0.7;
    } else if (variance < 1500) {
      // Medium distance
      distance = 1.5;
      confidence = 0.6;
    } else if (variance < 3000) {
      // Farther
      distance = 2.5;
      confidence = 0.5;
    } else {
      // High variance usually means open space or complex scene
      return null;
    }
    
    // Adjust based on brightness - darker often means closer
    if (mean < 40) {
      distance *= 0.5; // Very dark - likely very close
      confidence += 0.1;
    } else if (mean < 80) {
      distance *= 0.7;
      confidence += 0.05;
    }
    
    // Edge density adjustment
    if (edgeDensity > 0.3 && variance < 1500) {
      // High edges with moderate variance = textured wall nearby
      distance *= 0.8;
      confidence += 0.05;
    }
    
    // Clamp values
    distance = distance.clamp(0.2, 5.0);
    confidence = confidence.clamp(0.4, 0.9);
    
    // Only report if we have reasonable confidence
    if (confidence < 0.5) return null;
    
    // Create bounding box based on direction
    BoundingBox boundingBox;
    switch (direction) {
      case ObjectDirection.left:
        boundingBox = const BoundingBox(left: 0.0, top: 0.3, right: 0.33, bottom: 0.7);
        break;
      case ObjectDirection.right:
        boundingBox = const BoundingBox(left: 0.67, top: 0.3, right: 1.0, bottom: 0.7);
        break;
      case ObjectDirection.center:
      default:
        boundingBox = const BoundingBox(left: 0.25, top: 0.3, right: 0.75, bottom: 0.7);
        break;
    }
    
    return DetectedObject(
      label: label,
      confidence: confidence,
      distance: distance,
      direction: direction,
      boundingBox: boundingBox,
    );
  }

  /// Convert our CameraImage to ML Kit's InputImage
  mlkit.InputImage? _convertToInputImage(CameraImage image) {
    try {
      // Get the format
      mlkit.InputImageFormat format;
      switch (image.format) {
        case ImageFormat.nv21:
          format = mlkit.InputImageFormat.nv21;
          break;
        case ImageFormat.yuv420:
          format = mlkit.InputImageFormat.yuv420;
          break;
        case ImageFormat.bgra8888:
          format = mlkit.InputImageFormat.bgra8888;
          break;
        default:
          format = mlkit.InputImageFormat.nv21;
      }

      // Get rotation
      mlkit.InputImageRotation rotation;
      switch (image.rotation) {
        case 0:
          rotation = mlkit.InputImageRotation.rotation0deg;
          break;
        case 90:
          rotation = mlkit.InputImageRotation.rotation90deg;
          break;
        case 180:
          rotation = mlkit.InputImageRotation.rotation180deg;
          break;
        case 270:
          rotation = mlkit.InputImageRotation.rotation270deg;
          break;
        default:
          rotation = mlkit.InputImageRotation.rotation0deg;
      }

      // Get bytes from first plane
      if (image.planes.isEmpty) {
        print('[ML DEBUG] No planes in camera image');
        return null;
      }

      // For YUV420/NV21, we need to concatenate all planes
      final allBytes = <int>[];
      for (final plane in image.planes) {
        allBytes.addAll(plane.bytes);
      }
      final bytes = Uint8List.fromList(allBytes);

      final metadata = mlkit.InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: image.planes.first.bytesPerRow,
      );

      return mlkit.InputImage.fromBytes(bytes: bytes, metadata: metadata);
    } catch (e) {
      print('[ML DEBUG] Error converting to InputImage: $e');
      return null;
    }
  }

  ObjectDirection _determineDirection(BoundingBox box) {
    final centerX = box.centerX;
    
    if (centerX < 0.33) {
      return ObjectDirection.left;
    } else if (centerX > 0.66) {
      return ObjectDirection.right;
    } else {
      return ObjectDirection.center;
    }
  }

  double _estimateDistanceFromBox(
    String label, 
    BoundingBox box, 
    int imageWidth, 
    int imageHeight,
  ) {
    // Use reference object height for distance estimation
    final referenceHeight = _objectReferenceHeights[label.toLowerCase()] ?? 1.0;
    
    // Calculate apparent height in image (normalized)
    final apparentHeight = box.height;
    
    // Simple pinhole camera model for distance estimation
    // d = (H * f) / h
    // Where H = real height, f = focal length (normalized), h = apparent height
    const focalLength = 1.0; // Normalized focal length
    
    if (apparentHeight <= 0) return 10.0; // Far away default
    
    final distance = (referenceHeight * focalLength) / apparentHeight;
    
    return distance.clamp(0.1, 10.0); // Clamp to reasonable range
  }

  @override
  double estimateDistance(DetectedObject object, int imageWidth, int imageHeight) {
    return _estimateDistanceFromBox(
      object.label, 
      object.boundingBox, 
      imageWidth, 
      imageHeight,
    );
  }

  @override
  Future<HandLandmarks?> detectHandLandmarks(CameraImage image) async {
    // Hand landmark detection not yet implemented with ML Kit
    // Would require google_mlkit_pose_detection or custom model
    return null;
  }

  @override
  Future<SignLanguageResult?> recognizeSign(HandLandmarks landmarks) async {
    // Sign language recognition not yet implemented
    // Would require custom model for ASL/BSL recognition
    return null;
  }

  @override
  Future<void> dispose() async {
    _mlKitObjectDetector?.close();
    _isInitialized = false;
    print('[ML DEBUG] ML Service disposed');
  }
}
