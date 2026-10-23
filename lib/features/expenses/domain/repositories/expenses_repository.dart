import '../../../../core/result.dart';
import '../entities/office_expense.dart';

abstract interface class ExpensesRepository {
  Future<Result<List<OfficeExpense>>> list();
  Future<Result<String>> create({
    required double amount,
    required String method,
    required String category,
    required String description,
  });
  Future<Result<void>> update({
    required String expenseId,
    required double amount,
    required String method,
    required String category,
    required String description,
    required String reason,
  });
  Future<Result<void>> delete({
    required String expenseId,
    required String reason,
  });
}
