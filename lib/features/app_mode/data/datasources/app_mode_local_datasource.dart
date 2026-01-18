import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/app_mode.dart';

/// Local data source for app mode persistence
abstract class AppModeLocalDataSource {
  /// Get the cached app mode
  Future<AppMode> getAppMode();
  
  /// Cache the app mode
  Future<void> setAppMode(AppMode mode);
  
  /// Stream of app mode changes
  Stream<AppMode> get appModeStream;
}

class AppModeLocalDataSourceImpl implements AppModeLocalDataSource {
  final SharedPreferences sharedPreferences;
  final _modeController = StreamController<AppMode>.broadcast();
  
  static const _keyAppMode = 'app_mode';

  AppModeLocalDataSourceImpl(this.sharedPreferences);

  @override
  Future<AppMode> getAppMode() async {
    final modeString = sharedPreferences.getString(_keyAppMode);
    
    if (modeString == null) {
      // Default to Deaf Mode on first launch
      return AppMode.deaf;
    }
    
    return modeString == 'blind' ? AppMode.blind : AppMode.deaf;
  }

  @override
  Future<void> setAppMode(AppMode mode) async {
    final modeString = mode == AppMode.blind ? 'blind' : 'deaf';
    await sharedPreferences.setString(_keyAppMode, modeString);
    _modeController.add(mode);
  }

  @override
  Stream<AppMode> get appModeStream => _modeController.stream;
}
