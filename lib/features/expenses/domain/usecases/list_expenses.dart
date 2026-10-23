import '../../../../core/result.dart';
import '../entities/office_expense.dart';
import '../repositories/expenses_repository.dart';

class ListExpenses {
  const ListExpenses(this.repository);
  final ExpensesRepository repository;
  Future<Result<List<OfficeExpense>>> call() => repository.list();
}
