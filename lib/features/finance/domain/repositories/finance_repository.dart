import '../../../../core/result.dart';
import '../entities/financial_movement.dart';
abstract interface class FinanceRepository {
 Future<Result<List<FinancialMovement>>> listMovements({DateTime? from, DateTime? to, String? type});
 Future<Result<String>> recordGeneralRevenue({required double amount, required String method, required String note});
 Future<Result<void>> deleteMovement({required String movementId, required String reason});
 Future<Result<void>> updateMovementNote({required String movementId, required String note, required String reason});
}
