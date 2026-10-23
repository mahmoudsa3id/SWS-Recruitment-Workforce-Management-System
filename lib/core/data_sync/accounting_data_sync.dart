import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import '../month_scope/accounting_month_scope.dart';

class AccountingDataSync {
  AccountingDataSync._();

  static final StreamController<void> _changes =
      StreamController<void>.broadcast();

  static Stream<void> get changes => _changes.stream;

  static void notifyChanged() => _changes.add(null);
}

abstract class AccountingSyncCubit<State> extends Cubit<State> {
  AccountingSyncCubit(super.initialState, {this.listenToMonthChanges = false}) {
    _subscription = AccountingDataSync.changes.listen((_) {
      if (!isClosed) unawaited(refreshAfterDataChange());
    });
    if (listenToMonthChanges) {
      AccountingMonthScope.selected.addListener(_onAccountingMonthChanged);
    }
  }

  final bool listenToMonthChanges;
  late final StreamSubscription<void> _subscription;

  void _onAccountingMonthChanged() {
    if (!isClosed) unawaited(refreshAfterDataChange());
  }

  Future<void> refreshAfterDataChange();

  @override
  Future<void> close() async {
    if (listenToMonthChanges) {
      AccountingMonthScope.selected.removeListener(_onAccountingMonthChanged);
    }
    await _subscription.cancel();
    await super.close();
  }
}
