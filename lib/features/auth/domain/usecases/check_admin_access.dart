import '../../../../core/result.dart';
import '../repository/auth_repository.dart';

class CheckAdminAccess {
  const CheckAdminAccess(this.repository);
  final AuthRepository repository;

  Future<Result<bool>> call(String userId) =>
      repository.checkAdminAccess(userId);
}
