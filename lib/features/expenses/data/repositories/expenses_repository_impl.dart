import 'package:dartz/dartz.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/result.dart';
import '../../domain/entities/office_expense.dart';
import '../../domain/repositories/expenses_repository.dart';
import '../datasources/expenses_remote_data_source.dart';
import '../models/office_expense_model.dart';

class ExpensesRepositoryImpl implements ExpensesRepository {
  ExpensesRepositoryImpl(this.remote);
  final ExpensesRemoteDataSource remote;
  @override
  Future<Result<List<OfficeExpense>>> list() async {
    try {
      return Right(
        (await remote.list())
            .map(OfficeExpenseModel.fromMap)
            .toList(growable: false),
      );
    } catch (e) {
      return Left(ServerFailure('تعذر تحميل المصروفات.', cause: e));
    }
  }

  @override
  Future<Result<String>> create({
    required double amount,
    required String method,
    required String category,
    required String description,
  }) async {
    if (!amount.isFinite || amount <= 0) {
      return const Left(ValidationFailure('المبلغ يجب أن يكون أكبر من صفر.'));
    }
    if (category.trim().isEmpty) {
      return const Left(ValidationFailure('تصنيف المصروف مطلوب.'));
    }
    if (!{
      'cash',
      'instapay',
      'bank_transfer',
      'wallet',
      'other',
    }.contains(method)) {
      return const Left(ValidationFailure('طريقة الدفع غير صحيحة.'));
    }
    try {
      return Right(
        await remote.create(
          amount: amount,
          method: method,
          category: category,
          description: description,
        ),
      );
    } catch (e) {
      return Left(
        ServerFailure('تعذر تسجيل المصروف. تأكد من أن الشهر مفتوح.', cause: e),
      );
    }
  }

  @override
  Future<Result<void>> update({
    required String expenseId,
    required double amount,
    required String method,
    required String category,
    required String description,
    required String reason,
  }) async {
    if (!amount.isFinite || amount <= 0) {
      return const Left(ValidationFailure('المبلغ يجب أن يكون أكبر من صفر.'));
    }
    if (category.trim().isEmpty) {
      return const Left(ValidationFailure('تصنيف المصروف مطلوب.'));
    }
    if (reason.trim().isEmpty) {
      return const Left(ValidationFailure('سبب التعديل مطلوب.'));
    }
    if (!{
      'cash',
      'instapay',
      'bank_transfer',
      'wallet',
      'other',
    }.contains(method)) {
      return const Left(ValidationFailure('طريقة الدفع غير صحيحة.'));
    }
    try {
      await remote.update(
        expenseId: expenseId,
        amount: amount,
        method: method,
        category: category,
        description: description,
        reason: reason,
      );
      return const Right(null);
    } catch (e) {
      return Left(
        ServerFailure('تعذر تعديل المصروف. تأكد أن الشهر مفتوح.', cause: e),
      );
    }
  }

  @override
  Future<Result<void>> delete({
    required String expenseId,
    required String reason,
  }) async {
    if (reason.trim().isEmpty) {
      return const Left(ValidationFailure('سبب الحذف مطلوب.'));
    }
    try {
      await remote.delete(expenseId: expenseId, reason: reason);
      return const Right(null);
    } catch (e) {
      return Left(
        ServerFailure(
          'تعذر حذف المصروف. قد يكون الشهر مقفولًا أو الحركة مرتبطة بسجل آخر.',
          cause: e,
        ),
      );
    }
  }
}
