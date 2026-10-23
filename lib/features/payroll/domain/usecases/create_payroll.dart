import '../../../../core/result.dart';
import '../repositories/payroll_repository.dart';

class CreatePayroll {
  const CreatePayroll(this.repository);
  final PayrollRepository repository;
  Future<Result<String>> call({
    required String employeeName,
    required DateTime monthStart,
    required double baseSalary,
    required double commission,
    required double deductions,
    required double bonus,
    required double overtimeHours,
    required double overtimeRate,
  }) => repository.create(
    employeeName: employeeName,
    monthStart: monthStart,
    baseSalary: baseSalary,
    commission: commission,
    deductions: deductions,
    bonus: bonus,
    overtimeHours: overtimeHours,
    overtimeRate: overtimeRate,
  );
}
