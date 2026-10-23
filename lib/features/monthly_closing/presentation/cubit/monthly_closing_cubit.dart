import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/data_sync/accounting_data_sync.dart';
import '../../domain/entities/monthly_closing.dart';
import '../../domain/usecases/close_month.dart';
import '../../domain/usecases/list_closings.dart';
import '../../domain/usecases/reopen_month.dart';

sealed class MonthlyClosingState {
  const MonthlyClosingState();
}

final class MonthlyClosingInitial extends MonthlyClosingState {
  const MonthlyClosingInitial();
}

final class MonthlyClosingLoading extends MonthlyClosingState {
  const MonthlyClosingLoading();
}

final class MonthlyClosingLoaded extends MonthlyClosingState {
  const MonthlyClosingLoaded(this.items);
  final List<MonthlyClosing> items;
}

final class MonthlyClosingFailure extends MonthlyClosingState {
  const MonthlyClosingFailure(this.message);
  final String message;
}

class MonthlyClosingCubit extends AccountingSyncCubit<MonthlyClosingState> {
  MonthlyClosingCubit(this._list, this._close, this._reopen)
    : super(const MonthlyClosingInitial());

  final ListClosings _list;
  final CloseMonth _close;
  final ReopenMonth _reopen;

  @override
  Future<void> refreshAfterDataChange() => load();

  Future<void> load() async {
    emit(const MonthlyClosingLoading());
    final result = await _list();
    result.fold(
      (failure) => emit(MonthlyClosingFailure(failure.message)),
      (items) => emit(MonthlyClosingLoaded(items)),
    );
  }

  Future<String?> closeMonth(DateTime month, {String note = ''}) async {
    final result = await _close(month, note: note);
    return result.fold((failure) => failure.message, (_) {
      AccountingDataSync.notifyChanged();
      return null;
    });
  }

  Future<String?> reopen(DateTime month, String reason) async {
    final result = await _reopen(month, reason);
    return result.fold((failure) => failure.message, (_) {
      AccountingDataSync.notifyChanged();
      return null;
    });
  }
}
