import '../../../../core/result.dart';
import '../repositories/finance_repository.dart';

class DeleteFinancialMovement {
  const DeleteFinancialMovement(this.repository);
  final FinanceRepository repository;
  Future<Result<void>> call({
    required String movementId,
    required String reason,
  }) => repository.deleteMovement(movementId: movementId, reason: reason);
}
