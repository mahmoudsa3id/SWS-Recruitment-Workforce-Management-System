import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/admin_session_model.dart';
class AuthRemoteDataSource {
  AuthRemoteDataSource(this.client);
  final SupabaseClient client;
  bool get isSignedIn => client.auth.currentSession != null;
  Future<AdminSessionModel> signIn(String email, String password) async {
    final response = await client.auth.signInWithPassword(email: email.trim(), password: password);
    final user = response.user;
    if (user == null) throw const AuthException('لم يتم إنشاء جلسة تسجيل دخول.');
    return AdminSessionModel.fromAuthUser(id: user.id, email: user.email, signedInAt: DateTime.now().toUtc());
  }
  Future<bool> hasAdminAccess(String userId) async {
    final profile = await client.from('profiles').select('role,is_active').eq('user_id', userId).maybeSingle();
    return profile != null && const {'admin', 'hr'}.contains(profile['role']) && profile['is_active'] == true;
  }
  Future<void> signOut() => client.auth.signOut();
}
