import '../../../../core/result.dart';
import '../repositories/settings_repository.dart';

class ClearLocalCache {
  const ClearLocalCache(this.repository);
  final SettingsRepository repository;
  Future<Result<void>> call() => repository.clearLocalCache();
}
