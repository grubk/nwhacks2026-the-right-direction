import '../../../../core/services/camera_service.dart';
import '../entities/navigation_alert.dart';

/// Repository interface for object detection operations
abstract class ObjectDetectionRepository {
  /// Start object detection
  Future<void> startDetection();
  
  /// Stop object detection
  Future<void> stopDetection();
  
  /// Stream of detected objects
  Stream<List<DetectedObject>> get objectStream;
  
  /// Stream of navigation alerts
  Stream<NavigationAlert> get alertStream;
  
  /// Check if detection is active
  bool get isDetecting;
  
  /// Check if LiDAR is available and active
  bool get isLidarActive;
  
  /// Enable/disable LiDAR (iOS only)
  Future<void> setLidarEnabled(bool enabled);
  
  /// Enable/disable TTS guidance
  Future<void> setTtsEnabled(bool enabled);
  
  /// Dispose resources
  Future<void> dispose();
}
