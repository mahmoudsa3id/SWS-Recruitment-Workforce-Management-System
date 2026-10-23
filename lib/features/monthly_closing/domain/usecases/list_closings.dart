import '../../../../core/result.dart';
import '../entities/monthly_closing.dart';
import '../repositories/monthly_closing_repository.dart';

class ListClosings {
  const ListClosings(this.repository);
  final MonthlyClosingRepository repository;
  Future<Result<List<MonthlyClosing>>> call() => repository.list();
}
