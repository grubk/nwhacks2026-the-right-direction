import '../entities/app_mode.dart';
import '../repositories/app_mode_repository.dart';

/// Use case for setting the app mode
class SetAppMode {
  final AppModeRepository repository;

  SetAppMode(this.repository);

  Future<void> call(AppMode mode) async {
    await repository.setAppMode(mode);
  }
}
