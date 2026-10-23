import '../../domain/entities/admin_session.dart';
class AdminSessionModel extends AdminSession {
  const AdminSessionModel({required super.userId, required super.email, required super.signedInAt});
  factory AdminSessionModel.fromAuthUser({required String id, String? email, DateTime? signedInAt}) => AdminSessionModel(userId: id, email: email ?? '', signedInAt: signedInAt ?? DateTime.now().toUtc());
}
