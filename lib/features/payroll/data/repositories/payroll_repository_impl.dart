import 'package:dartz/dartz.dart';
import 'package:flutter/foundation.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/result.dart';
import '../../domain/entities/payroll_record.dart';
import '../../domain/repositories/payroll_repository.dart';
import '../datasources/payroll_remote_data_source.dart';
import '../models/payroll_record_model.dart';

class PayrollRepositoryImpl implements PayrollRepository {
  PayrollRepositoryImpl(this.remote);
  final PayrollRemoteDataSource remote;
  @override
  Future<Result<List<PayrollRecord>>> list() async {
    try {
      return Right(
        (await remote.list())
            .map(PayrollRecordModel.fromMap)
            .toList(growable: false),
      );
    } catch (e) {
      return Left(ServerFailure('تعذر تحميل سجل المرتبات.', cause: e));
    }
  }

  @override
  Future<Result<String>> create({
    required String employeeName,
    required DateTime monthStart,
    required double baseSalary,
    required double commission,
    required double deductions,
    required double bonus,
    required double overtimeHours,
    required double overtimeRate,
  }) async {
    if (employeeName.trim().isEmpty) {
      return const Left(ValidationFailure('اسم الموظف مطلوب.'));
    }
    if ([
      baseSalary,
      commission,
      deductions,
      bonus,
      overtimeHours,
      overtimeRate,
    ].any((v) => !v.isFinite || v < 0)) {
      return const Left(
        ValidationFailure(
          'قيم الراتب والعمولة والخصم يجب أن تكون موجبة أو صفرًا.',
        ),
      );
    }
    if (deductions >
        baseSalary + commission + bonus + (overtimeHours * overtimeRate)) {
      return const Left(
        ValidationFailure('الخصومات لا يمكن أن تتجاوز الأساسي والعمولة.'),
      );
    }
    try {
      return Right(
        await remote.create(
          employeeName: employeeName,
          monthStart: DateTime(monthStart.year, monthStart.month, 1),
          baseSalary: baseSalary,
          commission: commission,
          deductions: deductions,
          bonus: bonus,
          overtimeHours: overtimeHours,
          overtimeRate: overtimeRate,
        ),
      );
    } catch (e) {
      return Left(
        ServerFailure(
          'تعذر إنشاء استحقاق الراتب. ربما يوجد استحقاق مكرر للموظف في الشهر نفسه.',
          cause: e,
        ),
      );
    }
  }

  @override
  Future<Result<String>> pay({
    required String payrollId,
    required double amount,
    required String method,
    required String note,
  }) async {
    if (payrollId.trim().isEmpty || !amount.isFinite || amount <= 0) {
      return const Left(ValidationFailure('بيانات الدفع غير صحيحة.'));
    }
    try {
      return Right(
        await remote.pay(
          payrollId: payrollId,
          amount: amount,
          method: method,
          note: note,
        ),
      );
    } catch (e) {
      return Left(
        ServerFailure(
          'تعذر تسجيل دفع الراتب. راجع الاستحقاق وحالة الشهر.',
          cause: e,
        ),
      );
    }
  }

  @override
  Future<Result<void>> update({
    required String payrollId,
    required String employeeName,
    required double baseSalary,
    required double commission,
    required double deductions,
    required double bonus,
    required double overtimeHours,
    required double overtimeRate,
  }) async {
    if (employeeName.trim().isEmpty) {
      return const Left(ValidationFailure('اسم الموظف مطلوب.'));
    }
    if ([
          baseSalary,
          commission,
          deductions,
          bonus,
          overtimeHours,
          overtimeRate,
        ].any((v) => !v.isFinite || v < 0) ||
        baseSalary <= 0) {
      return const Left(ValidationFailure('قيم الراتب غير صحيحة.'));
    }
    if (deductions >
        baseSalary + commission + bonus + overtimeHours * overtimeRate) {
      return const Left(ValidationFailure('الخصومات تتجاوز إجمالي الاستحقاق.'));
    }
    try {
      await remote.update(
        payrollId: payrollId,
        employeeName: employeeName,
        baseSalary: baseSalary,
        commission: commission,
        deductions: deductions,
        bonus: bonus,
        overtimeHours: overtimeHours,
        overtimeRate: overtimeRate,
      );
      return const Right(null);
    } catch (e) {
      return Left(
        ServerFailure(
          'تعذر تعديل المرتب. إذا تم صرف جزء منه، يجب تسوية الدفعات أولًا.',
          cause: e,
        ),
      );
    }
  }

  @override
  Future<Result<void>> delete({
    required String payrollId,
    required String reason,
  }) async {
    if (reason.trim().isEmpty) {
      return const Left(ValidationFailure('سبب الحذف مطلوب.'));
    }

    try {
      await remote.delete(payrollId: payrollId, reason: reason.trim());

      return const Right(null);
    } catch (e, stackTrace) {
      debugPrint('Payroll delete error: $e');
      debugPrintStack(stackTrace: stackTrace);

      return Left(ServerFailure('تعذر حذف استحقاق المرتب: $e', cause: e));
    }
  }
}
