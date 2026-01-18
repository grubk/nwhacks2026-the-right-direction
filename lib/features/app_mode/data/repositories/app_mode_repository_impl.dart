import '../../domain/entities/app_mode.dart';
import '../../domain/repositories/app_mode_repository.dart';
import '../datasources/app_mode_local_datasource.dart';

class AppModeRepositoryImpl implements AppModeRepository {
  final AppModeLocalDataSource localDataSource;

  AppModeRepositoryImpl(this.localDataSource);

  @override
  Future<AppMode> getAppMode() async {
    return await localDataSource.getAppMode();
  }

  @override
  Future<void> setAppMode(AppMode mode) async {
    await localDataSource.setAppMode(mode);
  }

  @override
  Stream<AppMode> get appModeStream => localDataSource.appModeStream;
}
