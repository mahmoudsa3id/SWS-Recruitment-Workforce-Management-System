import 'package:dartz/dartz.dart';
import 'package:flutter/foundation.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/result.dart';
import '../../domain/entities/financial_movement.dart';
import '../../domain/repositories/finance_repository.dart';
import '../datasources/finance_remote_data_source.dart';
import '../models/financial_movement_model.dart';

class FinanceRepositoryImpl implements FinanceRepository {
  FinanceRepositoryImpl(this.remote);
  final FinanceRemoteDataSource remote;
  @override
  Future<Result<List<FinancialMovement>>> listMovements({
    DateTime? from,
    DateTime? to,
    String? type,
  }) async {
    try {
      final rows = await remote.list(from: from, to: to, type: type);
      return Right(
        rows.map(FinancialMovementModel.fromMap).toList(growable: false),
      );
    } catch (e) {
      return Left(ServerFailure('تعذر تحميل الحركات المالية.', cause: e));
    }
  }

  @override
  Future<Result<String>> recordGeneralRevenue({
    required double amount,
    required String method,
    required String note,
  }) async {
    if (!amount.isFinite || amount <= 0) {
      return const Left(ValidationFailure('المبلغ يجب أن يكون أكبر من صفر.'));
    }
    if (note.trim().isEmpty) {
      return const Left(ValidationFailure('بيان الإيراد مطلوب.'));
    }
    if (!_methods.contains(method)) {
      return const Left(ValidationFailure('طريقة الدفع غير صحيحة.'));
    }
    try {
      return Right(
        await remote.generalRevenue(amount: amount, method: method, note: note),
      );
    } catch (e) {
      return Left(
        ServerFailure(
          'تعذر تسجيل الإيراد. حدّث الحركات قبل إعادة المحاولة.',
          cause: e,
        ),
      );
    }
  }

  @override
  Future<Result<void>> deleteMovement({
    required String movementId,
    required String reason,
  }) async {
    if (movementId.trim().isEmpty) {
      return const Left(ValidationFailure('الحركة المالية غير محددة.'));
    }

    if (reason.trim().isEmpty) {
      return const Left(ValidationFailure('سبب الحذف مطلوب.'));
    }

    try {
      await remote.deleteMovement(id: movementId.trim(), reason: reason.trim());

      return const Right(null);
    } catch (e, stackTrace) {
      debugPrint('Delete movement failed: $e');
      debugPrintStack(stackTrace: stackTrace);

      return Left(ServerFailure('تعذر حذف الحركة المالية: $e', cause: e));
    }
  }

  @override
  Future<Result<void>> updateMovementNote({
    required String movementId,
    required String note,
    required String reason,
  }) async {
    if (movementId.trim().isEmpty) {
      return const Left(ValidationFailure('الحركة المالية غير محددة.'));
    }
    if (reason.trim().isEmpty) {
      return const Left(ValidationFailure('سبب التعديل مطلوب.'));
    }
    try {
      await remote.updateNote(id: movementId, note: note, reason: reason);
      return const Right(null);
    } catch (e) {
      return Left(
        ServerFailure('تعذر تعديل بيان الحركة. تأكد أن الشهر مفتوح.', cause: e),
      );
    }
  }

  static const _methods = {
    'cash',
    'instapay',
    'bank_transfer',
    'wallet',
    'other',
  };
}
