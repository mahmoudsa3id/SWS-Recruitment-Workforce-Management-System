import '../../../../core/data_sync/accounting_data_sync.dart';
import '../../domain/entities/financial_movement.dart';
import '../../domain/usecases/list_financial_movements.dart';
import '../../domain/usecases/record_general_revenue.dart';
import '../../domain/usecases/delete_financial_movement.dart';
import '../../domain/repositories/finance_repository.dart';

sealed class FinanceState {
  const FinanceState();
}

final class FinanceInitial extends FinanceState {
  const FinanceInitial();
}

final class FinanceLoading extends FinanceState {
  const FinanceLoading();
}

final class FinanceLoaded extends FinanceState {
  const FinanceLoaded(this.items);
  final List<FinancialMovement> items;
  double get totalIn => items
      .where((e) => e.isLedgerEvent && e.isCredit)
      .fold(0, (s, e) => s + e.amount);
  double get totalOut => items
      .where((e) => e.isLedgerEvent && !e.isCredit)
      .fold(0, (s, e) => s + e.amount);
  double get net => totalIn - totalOut;
}

final class FinanceFailure extends FinanceState {
  const FinanceFailure(this.message);
  final String message;
}

class FinanceCubit extends AccountingSyncCubit<FinanceState> {
  FinanceCubit(
    this._list,
    this._revenue,
    this._deleteMovement,
    this._repository,
  ) : super(const FinanceInitial(), listenToMonthChanges: true);
  final ListFinancialMovements _list;
  final RecordGeneralRevenue _revenue;
  final DeleteFinancialMovement _deleteMovement;
  final FinanceRepository _repository;
  String? lastReceiptNo;
  DateTime? _from;
  DateTime? _to;
  String? _type;

  @override
  Future<void> refreshAfterDataChange() => load();

  Future<void> load({DateTime? from, DateTime? to, String? type}) async {
    _from = from ?? _from;
    _to = to ?? _to;
    _type = type ?? _type;
    emit(const FinanceLoading());
    final r = await _list(from: _from, to: _to, type: _type);
    r.fold(
      (f) => emit(FinanceFailure(f.message)),
      (v) => emit(FinanceLoaded(v)),
    );
  }

  Future<String?> addRevenue({
    required double amount,
    required String method,
    required String note,
  }) async {
    lastReceiptNo = null;
    final r = await _revenue(amount: amount, method: method, note: note);
    return r.fold((f) => f.message, (id) {
      lastReceiptNo = id;
      AccountingDataSync.notifyChanged();
      return null;
    });
  }

  Future<String?> deleteMovement({
    required String id,
    required String reason,
  }) async {
    final r = await _deleteMovement(movementId: id, reason: reason);
    return r.fold((f) => f.message, (_) {
      AccountingDataSync.notifyChanged();
      return null;
    });
  }

  Future<String?> updateNote({
    required String id,
    required String note,
    required String reason,
  }) async {
    final r = await _repository.updateMovementNote(
      movementId: id,
      note: note,
      reason: reason,
    );
    return r.fold((f) => f.message, (_) {
      AccountingDataSync.notifyChanged();
      return null;
    });
  }
}
