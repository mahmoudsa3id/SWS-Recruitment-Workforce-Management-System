import 'package:dartz/dartz.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/result.dart';
import '../../domain/entities/audit_entry.dart';
import '../../domain/repositories/audit_repository.dart';
import '../datasources/audit_remote_data_source.dart';
import '../models/audit_entry_model.dart';

class AuditRepositoryImpl implements AuditRepository {
  AuditRepositoryImpl(this.remote);
  final AuditRemoteDataSource remote;
  @override
  Future<Result<List<AuditEntry>>> list({int limit = 300}) async {
    try {
      return Right(
        (await remote.list(
          limit,
        )).map(AuditEntryModel.fromMap).toList(growable: false),
      );
    } catch (e) {
      return Left(ServerFailure('تعذر تحميل سجل المراجعة.', cause: e));
    }
  }
}
