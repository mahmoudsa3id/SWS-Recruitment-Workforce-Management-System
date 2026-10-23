import '../../../../core/result.dart';
import '../entities/monthly_financial_report.dart';

abstract interface class ReportsRepository {
  Future<Result<MonthlyFinancialReport>> monthly(DateTime month);
}
