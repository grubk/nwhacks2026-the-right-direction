import '../../../../core/services/camera_service.dart';
import '../entities/navigation_alert.dart';
import '../repositories/object_detection_repository.dart';

/// Use case for detecting objects in camera feed
class DetectObjects {
  final ObjectDetectionRepository repository;

  DetectObjects(this.repository);

  Future<void> start() async {
    await repository.startDetection();
  }

  Future<void> stop() async {
    await repository.stopDetection();
  }

  Stream<List<DetectedObject>> get objectStream => repository.objectStream;

  Stream<NavigationAlert> get alertStream => repository.alertStream;

  bool get isDetecting => repository.isDetecting;

  bool get isLidarActive => repository.isLidarActive;

  Future<void> setLidarEnabled(bool enabled) async {
    await repository.setLidarEnabled(enabled);
  }

  Future<void> setTtsEnabled(bool enabled) async {
    await repository.setTtsEnabled(enabled);
  }
}
