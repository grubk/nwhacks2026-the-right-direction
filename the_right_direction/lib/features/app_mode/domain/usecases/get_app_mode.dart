import '../entities/app_mode.dart';
import '../repositories/app_mode_repository.dart';

/// Use case for getting the current app mode
class GetAppMode {
  final AppModeRepository repository;

  GetAppMode(this.repository);

  Future<AppMode> call() async {
    return await repository.getAppMode();
  }

  Stream<AppMode> get stream => repository.appModeStream;
}
