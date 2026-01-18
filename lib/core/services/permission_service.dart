import 'dart:io';
import 'package:permission_handler/permission_handler.dart' as ph;

/// Permission service abstraction
/// Handles platform-specific permission requests
abstract class PermissionService {
  /// Check if camera permission is granted
  Future<bool> hasCameraPermission();
  
  /// Request camera permission
  Future<PermissionResult> requestCameraPermission();
  
  /// Check if microphone permission is granted
  Future<bool> hasMicrophonePermission();
  
  /// Request microphone permission
  Future<PermissionResult> requestMicrophonePermission();
  
  /// Check if speech recognition permission is granted (iOS specific)
  Future<bool> hasSpeechRecognitionPermission();
  
  /// Request speech recognition permission
  Future<PermissionResult> requestSpeechRecognitionPermission();
  
  /// Check all required permissions for blind mode
  Future<PermissionStatus> checkBlindModePermissions();
  
  /// Check all required permissions for deaf mode
  Future<PermissionStatus> checkDeafModePermissions();
  
  /// Request all permissions for blind mode
  Future<Map<AppPermission, PermissionResult>> requestBlindModePermissions();
  
  /// Request all permissions for deaf mode
  Future<Map<AppPermission, PermissionResult>> requestDeafModePermissions();
  
  /// Open app settings
  Future<bool> openSettings();
  
  /// Check if permission is permanently denied
  Future<bool> isPermanentlyDenied(AppPermission permission);
}

enum AppPermission {
  camera,
  microphone,
  speech,
  storage,
  notification,
}

enum PermissionResult {
  granted,
  denied,
  permanentlyDenied,
  restricted,
  limited,
}

class PermissionStatus {
  final bool allGranted;
  final Map<AppPermission, PermissionResult> permissions;
  final List<AppPermission> missingPermissions;

  const PermissionStatus({
    required this.allGranted,
    required this.permissions,
    required this.missingPermissions,
  });
}

class PermissionServiceImpl implements PermissionService {
  @override
  Future<bool> hasCameraPermission() async {
    final status = await ph.Permission.camera.status;
    return status.isGranted;
  }

  @override
  Future<PermissionResult> requestCameraPermission() async {
    final status = await ph.Permission.camera.request();
    return _mapStatus(status);
  }

  @override
  Future<bool> hasMicrophonePermission() async {
    final status = await ph.Permission.microphone.status;
    return status.isGranted;
  }

  @override
  Future<PermissionResult> requestMicrophonePermission() async {
    final status = await ph.Permission.microphone.request();
    return _mapStatus(status);
  }

  @override
  Future<bool> hasSpeechRecognitionPermission() async {
    if (Platform.isIOS) {
      final status = await ph.Permission.speech.status;
      return status.isGranted;
    }
    // Android uses microphone permission for speech
    return await hasMicrophonePermission();
  }

  @override
  Future<PermissionResult> requestSpeechRecognitionPermission() async {
    if (Platform.isIOS) {
      final status = await ph.Permission.speech.request();
      return _mapStatus(status);
    }
    // Android uses microphone permission for speech
    return await requestMicrophonePermission();
  }

  @override
  Future<PermissionStatus> checkBlindModePermissions() async {
    final permissions = <AppPermission, PermissionResult>{};
    final missing = <AppPermission>[];

    // Camera is required for blind mode
    final cameraStatus = await ph.Permission.camera.status;
    permissions[AppPermission.camera] = _mapStatus(cameraStatus);
    if (!cameraStatus.isGranted) {
      missing.add(AppPermission.camera);
    }

    return PermissionStatus(
      allGranted: missing.isEmpty,
      permissions: permissions,
      missingPermissions: missing,
    );
  }

  @override
  Future<PermissionStatus> checkDeafModePermissions() async {
    final permissions = <AppPermission, PermissionResult>{};
    final missing = <AppPermission>[];

    // Camera is required for sign language recognition
    final cameraStatus = await ph.Permission.camera.status;
    permissions[AppPermission.camera] = _mapStatus(cameraStatus);
    if (!cameraStatus.isGranted) {
      missing.add(AppPermission.camera);
    }

    // Microphone is required for speech-to-text
    final micStatus = await ph.Permission.microphone.status;
    permissions[AppPermission.microphone] = _mapStatus(micStatus);
    if (!micStatus.isGranted) {
      missing.add(AppPermission.microphone);
    }

    // Speech recognition permission (iOS only)
    if (Platform.isIOS) {
      final speechStatus = await ph.Permission.speech.status;
      permissions[AppPermission.speech] = _mapStatus(speechStatus);
      if (!speechStatus.isGranted) {
        missing.add(AppPermission.speech);
      }
    }

    return PermissionStatus(
      allGranted: missing.isEmpty,
      permissions: permissions,
      missingPermissions: missing,
    );
  }

  @override
  Future<Map<AppPermission, PermissionResult>> requestBlindModePermissions() async {
    final results = <AppPermission, PermissionResult>{};

    results[AppPermission.camera] = await requestCameraPermission();

    return results;
  }

  @override
  Future<Map<AppPermission, PermissionResult>> requestDeafModePermissions() async {
    final results = <AppPermission, PermissionResult>{};

    results[AppPermission.camera] = await requestCameraPermission();
    results[AppPermission.microphone] = await requestMicrophonePermission();
    
    if (Platform.isIOS) {
      results[AppPermission.speech] = await requestSpeechRecognitionPermission();
    }

    return results;
  }

  @override
  Future<bool> openSettings() async {
    return await ph.openAppSettings();
  }

  @override
  Future<bool> isPermanentlyDenied(AppPermission permission) async {
    final nativePermission = _mapAppPermission(permission);
    if (nativePermission == null) return false;
    
    final status = await nativePermission.status;
    return status.isPermanentlyDenied;
  }

  ph.Permission? _mapAppPermission(AppPermission permission) {
    switch (permission) {
      case AppPermission.camera:
        return ph.Permission.camera;
      case AppPermission.microphone:
        return ph.Permission.microphone;
      case AppPermission.speech:
        return Platform.isIOS ? ph.Permission.speech : ph.Permission.microphone;
      case AppPermission.storage:
        return ph.Permission.storage;
      case AppPermission.notification:
        return ph.Permission.notification;
    }
  }

  PermissionResult _mapStatus(ph.PermissionStatus status) {
    if (status.isGranted) return PermissionResult.granted;
    if (status.isDenied) return PermissionResult.denied;
    if (status.isPermanentlyDenied) return PermissionResult.permanentlyDenied;
    if (status.isRestricted) return PermissionResult.restricted;
    if (status.isLimited) return PermissionResult.limited;
    return PermissionResult.denied;
  }
}
