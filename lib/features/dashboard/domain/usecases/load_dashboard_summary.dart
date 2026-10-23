import '../../../../core/result.dart';
import '../entities/dashboard_summary.dart';
import '../repositories/dashboard_repository.dart';

class LoadDashboardSummary {
  const LoadDashboardSummary(this.repository);
  final DashboardRepository repository;
  Future<Result<DashboardSummary>> call() => repository.loadSummary();
}
