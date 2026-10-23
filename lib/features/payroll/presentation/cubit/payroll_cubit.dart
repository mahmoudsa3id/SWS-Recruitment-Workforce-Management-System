import '../../../../core/data_sync/accounting_data_sync.dart';
import '../../domain/entities/payroll_record.dart';
import '../../domain/usecases/create_payroll.dart';
import '../../domain/usecases/list_payroll.dart';
import '../../domain/usecases/pay_payroll.dart';
import '../../domain/repositories/payroll_repository.dart';

sealed class PayrollState {
  const PayrollState();
}

final class PayrollInitial extends PayrollState {
  const PayrollInitial();
}

final class PayrollLoading extends PayrollState {
  const PayrollLoading();
}

final class PayrollLoaded extends PayrollState {
  const PayrollLoaded(this.records);
  final List<PayrollRecord> records;

  double get totalDue =>
      records.fold(0.0, (sum, record) => sum + record.outstanding);
}

final class PayrollFailure extends PayrollState {
  const PayrollFailure(this.message);
  final String message;
}

class PayrollCubit extends AccountingSyncCubit<PayrollState> {
  PayrollCubit(this._list, this._create, this._pay, this._repository)
    : super(const PayrollInitial(), listenToMonthChanges: true);

  final ListPayroll _list;
  final CreatePayroll _create;
  final PayPayroll _pay;
  final PayrollRepository _repository;

  String? lastReceiptNo;

  @override
  Future<void> refreshAfterDataChange() => load();

  Future<void> load() async {
    emit(const PayrollLoading());
    final result = await _list();
    result.fold(
      (failure) => emit(PayrollFailure(failure.message)),
      (records) => emit(PayrollLoaded(records)),
    );
  }

  Future<String?> create({
    required String employeeName,
    required DateTime monthStart,
    required double baseSalary,
    required double commission,
    required double deductions,
    required double bonus,
    required double overtimeHours,
    required double overtimeRate,
  }) async {
    final result = await _create(
      employeeName: employeeName,
      monthStart: monthStart,
      baseSalary: baseSalary,
      commission: commission,
      deductions: deductions,
      bonus: bonus,
      overtimeHours: overtimeHours,
      overtimeRate: overtimeRate,
    );
    return result.fold((failure) => failure.message, (_) {
      AccountingDataSync.notifyChanged();
      return null;
    });
  }

  Future<String?> pay({
    required String payrollId,
    required double amount,
    required String method,
    required String note,
  }) async {
    lastReceiptNo = null;
    final result = await _pay(
      payrollId: payrollId,
      amount: amount,
      method: method,
      note: note,
    );
    return result.fold((failure) => failure.message, (receipt) {
      lastReceiptNo = receipt;
      AccountingDataSync.notifyChanged();
      return null;
    });
  }

  Future<String?> updateRecord({
    required String payrollId,
    required String employeeName,
    required double baseSalary,
    required double commission,
    required double deductions,
    required double bonus,
    required double overtimeHours,
    required double overtimeRate,
  }) async {
    final result = await _repository.update(
      payrollId: payrollId,
      employeeName: employeeName,
      baseSalary: baseSalary,
      commission: commission,
      deductions: deductions,
      bonus: bonus,
      overtimeHours: overtimeHours,
      overtimeRate: overtimeRate,
    );
    return result.fold((failure) => failure.message, (_) {
      AccountingDataSync.notifyChanged();
      return null;
    });
  }

  Future<String?> deleteRecord({
    required String payrollId,
    required String reason,
  }) async {
    final result = await _repository.delete(
      payrollId: payrollId,
      reason: reason,
    );
    return result.fold((failure) => failure.message, (_) {
      AccountingDataSync.notifyChanged();
      return null;
    });
  }
}
