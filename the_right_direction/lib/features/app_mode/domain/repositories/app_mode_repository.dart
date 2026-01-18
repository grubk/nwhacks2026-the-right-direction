import '../entities/app_mode.dart';

/// Repository interface for app mode persistence
abstract class AppModeRepository {
  /// Get the current app mode
  Future<AppMode> getAppMode();
  
  /// Set the app mode
  Future<void> setAppMode(AppMode mode);
  
  /// Stream of app mode changes
  Stream<AppMode> get appModeStream;
}
