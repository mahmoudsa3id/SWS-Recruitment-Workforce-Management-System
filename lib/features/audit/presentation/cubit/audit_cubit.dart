import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/data_sync/accounting_data_sync.dart';
import '../../domain/entities/audit_entry.dart';
import '../../domain/usecases/list_audit_entries.dart';

sealed class AuditState {
  const AuditState();
}

final class AuditInitial extends AuditState {
  const AuditInitial();
}

final class AuditLoading extends AuditState {
  const AuditLoading();
}

final class AuditLoaded extends AuditState {
  const AuditLoaded(this.items);
  final List<AuditEntry> items;
}

final class AuditFailure extends AuditState {
  const AuditFailure(this.message);
  final String message;
}

class AuditCubit extends AccountingSyncCubit<AuditState> {
  AuditCubit(this._list)
    : super(const AuditInitial(), listenToMonthChanges: true);

  final ListAuditEntries _list;

  @override
  Future<void> refreshAfterDataChange() => load();

  Future<void> load() async {
    emit(const AuditLoading());
    final result = await _list();
    result.fold(
      (failure) => emit(AuditFailure(failure.message)),
      (items) => emit(AuditLoaded(items)),
    );
  }
}
