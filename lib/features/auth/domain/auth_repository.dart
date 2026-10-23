import '../../../core/result.dart';
import 'entities/admin_session.dart';
abstract interface class AuthRepository {
  Future<Result<AdminSession>> signIn(String email, String password);
  Future<Result<bool>> checkAdminAccess(String userId);
  Future<void> signOut();
  bool get isSignedIn;
}
