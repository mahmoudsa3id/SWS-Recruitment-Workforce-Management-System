import '../../../../core/result.dart';
import '../auth_repository.dart';
import '../entities/admin_session.dart';

class SignIn {
  const SignIn(this.repository);
  final AuthRepository repository;
  Future<Result<AdminSession>> call(String email, String password) =>
      repository.signIn(email, password);
}
