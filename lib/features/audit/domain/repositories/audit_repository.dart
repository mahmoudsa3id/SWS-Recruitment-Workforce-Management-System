import '../../../../core/result.dart';
import '../entities/audit_entry.dart';

abstract interface class AuditRepository {
  Future<Result<List<AuditEntry>>> list({int limit = 10});
}
