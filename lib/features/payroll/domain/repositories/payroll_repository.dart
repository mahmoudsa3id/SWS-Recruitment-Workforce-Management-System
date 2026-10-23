import '../../../../core/result.dart';
import '../entities/payroll_record.dart';

abstract interface class PayrollRepository {
  Future<Result<List<PayrollRecord>>> list();
  Future<Result<String>> create({
    required String employeeName,
    required DateTime monthStart,
    required double baseSalary,
    required double commission,
    required double deductions,
    required double bonus,
    required double overtimeHours,
    required double overtimeRate,
  });
  Future<Result<String>> pay({
    required String payrollId,
    required double amount,
    required String method,
    required String note,
  });
  Future<Result<void>> update({
    required String payrollId,
    required String employeeName,
    required double baseSalary,
    required double commission,
    required double deductions,
    required double bonus,
    required double overtimeHours,
    required double overtimeRate,
  });
  Future<Result<void>> delete({
    required String payrollId,
    required String reason,
  });
}
