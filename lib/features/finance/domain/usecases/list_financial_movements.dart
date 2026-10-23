import '../../../../core/result.dart';
import '../entities/financial_movement.dart';
import '../repositories/finance_repository.dart';

class ListFinancialMovements {
  const ListFinancialMovements(this.repository);
  final FinanceRepository repository;
  Future<Result<List<FinancialMovement>>> call({
    DateTime? from,
    DateTime? to,
    String? type,
  }) => repository.listMovements(from: from, to: to, type: type);
}
