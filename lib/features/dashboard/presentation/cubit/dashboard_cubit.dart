import '../../../../core/data_sync/accounting_data_sync.dart';
import '../../domain/entities/dashboard_summary.dart';
import '../../domain/usecases/load_dashboard_summary.dart';

sealed class DashboardState {
  const DashboardState();
}

final class DashboardInitial extends DashboardState {
  const DashboardInitial();
}

final class DashboardLoading extends DashboardState {
  const DashboardLoading();
}

final class DashboardLoaded extends DashboardState {
  const DashboardLoaded(this.summary);
  final DashboardSummary summary;
}

final class DashboardFailure extends DashboardState {
  const DashboardFailure(this.message);
  final String message;
}

class DashboardCubit extends AccountingSyncCubit<DashboardState> {
  DashboardCubit(this._load)
    : super(const DashboardInitial(), listenToMonthChanges: true);

  final LoadDashboardSummary _load;

  @override
  Future<void> refreshAfterDataChange() => load();

  Future<void> load() async {
    emit(const DashboardLoading());
    final result = await _load();
    result.fold(
      (failure) => emit(DashboardFailure(failure.message)),
      (summary) => emit(DashboardLoaded(summary)),
    );
  }
}
