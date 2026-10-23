import '../../../../core/result.dart';
import '../entities/payroll_record.dart';
import '../repositories/payroll_repository.dart';

class ListPayroll {
  const ListPayroll(this.repository);
  final PayrollRepository repository;
  Future<Result<List<PayrollRecord>>> call() => repository.list();
}
