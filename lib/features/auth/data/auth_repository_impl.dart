import 'package:dartz/dartz.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/errors/failure.dart';
import '../../../core/result.dart';
import '../domain/auth_repository.dart';
import '../domain/entities/admin_session.dart';
import 'datasources/auth_remote_data_source.dart';
class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl(this.remote);
  final AuthRemoteDataSource remote;
  @override bool get isSignedIn => remote.isSignedIn;
  @override Future<Result<AdminSession>> signIn(String email, String password) async {
    if (email.trim().isEmpty || password.isEmpty) return const Left(ValidationFailure('أدخل البريد الإلكتروني وكلمة المرور.'));
    try { final session = await remote.signIn(email, password); return Right(session); }
    on AuthException catch (e) { return Left(AuthFailure(_authMessage(e), cause: e)); }
    catch (e) { return Left(ServerFailure('تعذر تسجيل الدخول. تحقق من الاتصال والبيانات.', cause: e)); }
  }
  @override Future<Result<bool>> checkAdminAccess(String userId) async {
    if (userId.trim().isEmpty) return const Left(AuthFailure('جلسة المستخدم غير صالحة.'));
    try { return Right(await remote.hasAdminAccess(userId)); }
    catch (e) { return Left(ServerFailure('تعذر التحقق من صلاحيات الحساب.', cause: e)); }
  }
  @override Future<void> signOut() => remote.signOut();
  String _authMessage(AuthException error) {
    final message = error.message.toLowerCase();
    if (message.contains('invalid login credentials')) return 'البريد الإلكتروني أو كلمة المرور غير صحيحة.';
    if (message.contains('email not confirmed')) return 'البريد الإلكتروني غير مؤكد.';
    return error.message;
  }
}
