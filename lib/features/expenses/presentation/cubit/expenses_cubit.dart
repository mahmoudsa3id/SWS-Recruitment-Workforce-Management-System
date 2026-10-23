import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/data_sync/accounting_data_sync.dart';
import '../../domain/entities/office_expense.dart';
import '../../domain/usecases/create_expense.dart';
import '../../domain/usecases/list_expenses.dart';
import '../../domain/repositories/expenses_repository.dart';

sealed class ExpensesState {
  const ExpensesState();
}

final class ExpensesInitial extends ExpensesState {
  const ExpensesInitial();
}

final class ExpensesLoading extends ExpensesState {
  const ExpensesLoading();
}

final class ExpensesLoaded extends ExpensesState {
  const ExpensesLoaded(this.items);
  final List<OfficeExpense> items;
}

final class ExpensesFailure extends ExpensesState {
  const ExpensesFailure(this.message);
  final String message;
}

class ExpensesCubit extends AccountingSyncCubit<ExpensesState> {
  ExpensesCubit(this._list, this._create, this._repository)
      : super(const ExpensesInitial(), listenToMonthChanges: true);

  final ListExpenses _list;
  final CreateExpense _create;
  final ExpensesRepository _repository;

  @override
  Future<void> refreshAfterDataChange() => load();

  Future<void> load() async {
    emit(const ExpensesLoading());
    final result = await _list();
    result.fold(
      (failure) => emit(ExpensesFailure(failure.message)),
      (items) => emit(ExpensesLoaded(items)),
    );
  }

  Future<String?> create({
    required double amount,
    required String method,
    required String category,
    required String description,
  }) async {
    final result = await _create(
      amount: amount,
      method: method,
      category: category,
      description: description,
    );
    return result.fold((failure) => failure.message, (_) {
      AccountingDataSync.notifyChanged();
      return null;
    });
  }

  Future<String?> updateExpense({
    required String expenseId,
    required double amount,
    required String method,
    required String category,
    required String description,
    required String reason,
  }) async {
    final result = await _repository.update(
      expenseId: expenseId,
      amount: amount,
      method: method,
      category: category,
      description: description,
      reason: reason,
    );
    return result.fold((failure) => failure.message, (_) {
      AccountingDataSync.notifyChanged();
      return null;
    });
  }

  Future<String?> deleteExpense({
    required String expenseId,
    required String reason,
  }) async {
    final result = await _repository.delete(
      expenseId: expenseId,
      reason: reason,
    );
    return result.fold((failure) => failure.message, (_) {
      AccountingDataSync.notifyChanged();
      return null;
    });
  }
}
