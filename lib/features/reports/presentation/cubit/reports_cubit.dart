import '../../../../core/data_sync/accounting_data_sync.dart';
import '../../../../core/month_scope/accounting_month_scope.dart';
import '../../domain/entities/monthly_financial_report.dart';
import '../../domain/usecases/load_monthly_report.dart';

sealed class ReportsState {
  const ReportsState();
}

final class ReportsInitial extends ReportsState {
  const ReportsInitial();
}

final class ReportsLoading extends ReportsState {
  const ReportsLoading();
}

final class ReportsLoaded extends ReportsState {
  const ReportsLoaded(this.report);
  final MonthlyFinancialReport report;
}

final class ReportsFailure extends ReportsState {
  const ReportsFailure(this.message);
  final String message;
}

class ReportsCubit extends AccountingSyncCubit<ReportsState> {
  ReportsCubit(this._load) : super(const ReportsInitial(), listenToMonthChanges: true);

  final LoadMonthlyReport _load;
  DateTime? _month;

  @override
  Future<void> refreshAfterDataChange() async {
    await load(AccountingMonthScope.start);
  }

  Future<void> load(DateTime month) async {
    _month = month;
    emit(const ReportsLoading());
    final result = await _load(month);
    result.fold(
      (failure) => emit(ReportsFailure(failure.message)),
      (report) => emit(ReportsLoaded(report)),
    );
  }
}
