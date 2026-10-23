import 'package:dartz/dartz.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/result.dart';
import '../../domain/entities/dashboard_summary.dart';
import '../../domain/repositories/dashboard_repository.dart';
import '../datasources/dashboard_remote_data_source.dart';
import '../models/dashboard_summary_model.dart';

class DashboardRepositoryImpl implements DashboardRepository {
  DashboardRepositoryImpl(this.remote);
  final DashboardRemoteDataSource remote;
  @override
  Future<Result<DashboardSummary>> loadSummary() async {
    try {
      return Right(DashboardSummaryModel.fromMap(await remote.fetchSummary()));
    } catch (e) {
      return Left(ServerFailure('تعذر تحميل ملخص لوحة التحكم.', cause: e));
    }
  }
}
