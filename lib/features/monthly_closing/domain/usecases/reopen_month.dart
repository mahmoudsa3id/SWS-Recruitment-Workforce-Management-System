import '../../../../core/result.dart';
import '../repositories/monthly_closing_repository.dart';

class ReopenMonth {
  const ReopenMonth(this.repository);
  final MonthlyClosingRepository repository;
  Future<Result<String>> call(DateTime month, String reason) =>
      repository.reopen(month, reason);
}
