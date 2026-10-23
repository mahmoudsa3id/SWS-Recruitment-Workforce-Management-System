import '../../../../core/result.dart';
import '../repositories/expenses_repository.dart';

class CreateExpense {
  const CreateExpense(this.repository);
  final ExpensesRepository repository;
  Future<Result<String>> call({
    required double amount,
    required String method,
    required String category,
    required String description,
  }) => repository.create(
    amount: amount,
    method: method,
    category: category,
    description: description,
  );
}
