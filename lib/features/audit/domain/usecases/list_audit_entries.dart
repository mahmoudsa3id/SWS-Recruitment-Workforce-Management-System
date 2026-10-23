import '../../../../core/result.dart';
import '../entities/audit_entry.dart';
import '../repositories/audit_repository.dart';

class ListAuditEntries {
  const ListAuditEntries(this.repository);
  final AuditRepository repository;
  Future<Result<List<AuditEntry>>> call({int limit = 10}) =>
      repository.list(limit: limit);
}
