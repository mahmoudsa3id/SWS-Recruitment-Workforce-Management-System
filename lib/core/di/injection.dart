import 'package:get_it/get_it.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../cache/local_cache.dart';
import '../../features/auth/data/repository/auth_repository_impl.dart';
import '../../features/auth/data/datasources/auth_remote_data_source.dart';
import '../../features/auth/domain/repository/auth_repository.dart';
import '../../features/auth/domain/usecases/sign_in.dart';
import '../../features/auth/domain/usecases/check_admin_access.dart';
import '../../features/auth/domain/usecases/sign_out.dart';
import '../../features/auth/presentation/cubit/auth_cubit.dart';
import '../../features/travelers/data/traveler_remote_data_source.dart';
import '../../features/travelers/data/traveler_repository_impl.dart';
import '../../features/travelers/data/datasources/traveler_export_remote_data_source.dart';
import '../../features/travelers/data/repositories/traveler_export_repository_impl.dart';
import '../../features/travelers/domain/repositories/traveler_export_repository.dart';
import '../../features/travelers/domain/usecases/export_traveler_file.dart';
import '../../features/travelers/domain/repositories/traveler_repository.dart';
import '../../features/travelers/domain/usecases/list_travelers.dart';
import '../../features/travelers/domain/usecases/create_traveler.dart';
import '../../features/travelers/domain/usecases/delete_traveler.dart';
import '../../features/travelers/domain/usecases/archive_traveler.dart';
import '../../features/travelers/domain/usecases/load_profile.dart';
import '../../features/travelers/domain/usecases/add_payment.dart';
import '../../features/travelers/domain/usecases/set_traveler_stage.dart';
import '../../features/travelers/domain/usecases/set_traveler_ticket_booking.dart';
import '../../features/travelers/domain/usecases/set_traveler_avatar.dart';
import '../../features/travelers/domain/usecases/update_traveler.dart';
import '../../features/travelers/presentation/cubit/travelers_cubit.dart';
import '../../features/travelers/presentation/cubit/traveler_profile_cubit.dart';
import '../../features/finance/data/datasources/finance_remote_data_source.dart';
import '../../features/finance/data/repositories/finance_repository_impl.dart';
import '../../features/finance/domain/repositories/finance_repository.dart';
import '../../features/finance/domain/usecases/list_financial_movements.dart';
import '../../features/finance/domain/usecases/record_general_revenue.dart';
import '../../features/finance/domain/usecases/delete_financial_movement.dart';
import '../../features/finance/presentation/cubit/finance_cubit.dart';
import '../../features/expenses/data/datasources/expenses_remote_data_source.dart';
import '../../features/expenses/data/repositories/expenses_repository_impl.dart';
import '../../features/expenses/domain/repositories/expenses_repository.dart';
import '../../features/expenses/domain/usecases/list_expenses.dart';
import '../../features/expenses/domain/usecases/create_expense.dart';
import '../../features/expenses/presentation/cubit/expenses_cubit.dart';
import '../../features/payroll/data/datasources/payroll_remote_data_source.dart';
import '../../features/payroll/data/repositories/payroll_repository_impl.dart';
import '../../features/payroll/domain/repositories/payroll_repository.dart';
import '../../features/payroll/domain/usecases/list_payroll.dart';
import '../../features/payroll/domain/usecases/create_payroll.dart';
import '../../features/payroll/domain/usecases/pay_payroll.dart';
import '../../features/payroll/presentation/cubit/payroll_cubit.dart';
import '../../features/monthly_closing/data/datasources/monthly_closing_remote_data_source.dart';
import '../../features/monthly_closing/data/repositories/monthly_closing_repository_impl.dart';
import '../../features/monthly_closing/domain/repositories/monthly_closing_repository.dart';
import '../../features/monthly_closing/domain/usecases/list_closings.dart';
import '../../features/monthly_closing/domain/usecases/close_month.dart';
import '../../features/monthly_closing/domain/usecases/reopen_month.dart';
import '../../features/monthly_closing/presentation/cubit/monthly_closing_cubit.dart';
import '../../features/documents/data/datasources/documents_remote_data_source.dart';
import '../../features/documents/data/repositories/documents_repository_impl.dart';
import '../../features/documents/domain/repositories/documents_repository.dart';
import '../../features/documents/domain/usecases/list_traveler_documents.dart';
import '../../features/documents/domain/usecases/upload_traveler_document.dart';
import '../../features/documents/domain/usecases/create_document_link.dart';
import '../../features/documents/domain/usecases/delete_traveler_document.dart';
import '../../features/documents/domain/usecases/download_traveler_document.dart';
import '../../features/documents/presentation/cubit/documents_cubit.dart';
import '../../features/reports/data/datasources/reports_remote_data_source.dart';
import '../../features/reports/data/repositories/reports_repository_impl.dart';
import '../../features/reports/domain/repositories/reports_repository.dart';
import '../../features/reports/domain/usecases/load_monthly_report.dart';
import '../../features/reports/presentation/cubit/reports_cubit.dart';
import '../../features/audit/data/datasources/audit_remote_data_source.dart';
import '../../features/audit/data/repositories/audit_repository_impl.dart';
import '../../features/audit/domain/repositories/audit_repository.dart';
import '../../features/audit/domain/usecases/list_audit_entries.dart';
import '../../features/audit/presentation/cubit/audit_cubit.dart';
import '../../features/settings/data/datasources/settings_local_data_source.dart';
import '../../features/settings/data/repositories/settings_repository_impl.dart';
import '../../features/settings/domain/repositories/settings_repository.dart';
import '../../features/settings/domain/usecases/load_system_settings.dart';
import '../../features/settings/domain/usecases/clear_local_cache.dart';
import '../../features/settings/presentation/cubit/settings_cubit.dart';
import '../../features/dashboard/data/datasources/dashboard_remote_data_source.dart';
import '../../features/dashboard/data/repositories/dashboard_repository_impl.dart';
import '../../features/dashboard/domain/repositories/dashboard_repository.dart';
import '../../features/dashboard/domain/usecases/load_dashboard_summary.dart';
import '../../features/dashboard/presentation/cubit/dashboard_cubit.dart';

final sl = GetIt.instance;

Future<void> configureDependencies(SupabaseClient client) async {
  if (sl.isRegistered<SupabaseClient>()) await sl.reset();
  final localCache = await LocalCache.create();
  sl.registerLazySingleton(() => client);
  sl.registerLazySingleton<LocalCache>(() => localCache);

  sl.registerLazySingleton(() => AuthRemoteDataSource(sl()));
  sl.registerLazySingleton<AuthRepository>(() => AuthRepositoryImpl(sl()));
  sl.registerLazySingleton(() => SignIn(sl()));
  sl.registerLazySingleton(() => CheckAdminAccess(sl()));
  sl.registerLazySingleton(() => SignOut(sl()));
  sl.registerFactory(() => AuthCubit(sl(), sl()));

  sl.registerLazySingleton<TravelerRemoteDataSource>(
    () => TravelerRemoteDataSourceImpl(sl()),
  );
  sl.registerLazySingleton<TravelerRepository>(
    () => TravelerRepositoryImpl(sl(), sl()),
  );
  sl.registerLazySingleton(() => ListTravelers(sl()));
  sl.registerLazySingleton(() => CreateTraveler(sl()));
  sl.registerLazySingleton(() => ArchiveTraveler(sl()));
  sl.registerLazySingleton(() => DeleteTraveler(sl()));
  sl.registerLazySingleton(() => LoadTravelerProfile(sl()));
  sl.registerLazySingleton(() => AddTravelerPayment(sl()));
  sl.registerLazySingleton(() => SetTravelerStage(sl()));
  sl.registerLazySingleton(() => SetTravelerTicketBooking(sl()));
  sl.registerLazySingleton(() => SetTravelerAvatar(sl()));
  sl.registerLazySingleton(() => UpdateTraveler(sl()));
  sl.registerLazySingleton(() => TravelerExportRemoteDataSource(sl()));
  sl.registerLazySingleton<TravelerExportRepository>(
    () => TravelerExportRepositoryImpl(sl(), sl(), sl()),
  );
  sl.registerLazySingleton(() => ExportTravelerFile(sl()));
  sl.registerFactory(() => TravelersCubit(sl(), sl(), sl(), sl(), sl()));
  sl.registerFactory(
    () => TravelerProfileCubit(sl(), sl(), sl(), sl(), sl(), sl()),
  );

  sl.registerLazySingleton(() => FinanceRemoteDataSource(sl()));
  sl.registerLazySingleton<FinanceRepository>(
    () => FinanceRepositoryImpl(sl()),
  );
  sl.registerLazySingleton(() => ListFinancialMovements(sl()));
  sl.registerLazySingleton(() => RecordGeneralRevenue(sl()));
  sl.registerLazySingleton(() => DeleteFinancialMovement(sl()));
  sl.registerFactory(() => FinanceCubit(sl(), sl(), sl(), sl()));

  sl.registerLazySingleton(() => ExpensesRemoteDataSource(sl()));
  sl.registerLazySingleton<ExpensesRepository>(
    () => ExpensesRepositoryImpl(sl()),
  );
  sl.registerLazySingleton(() => ListExpenses(sl()));
  sl.registerLazySingleton(() => CreateExpense(sl()));
  sl.registerFactory(() => ExpensesCubit(sl(), sl(), sl()));

  sl.registerLazySingleton(() => PayrollRemoteDataSource(sl()));
  sl.registerLazySingleton<PayrollRepository>(
    () => PayrollRepositoryImpl(sl()),
  );
  sl.registerLazySingleton(() => ListPayroll(sl()));
  sl.registerLazySingleton(() => CreatePayroll(sl()));
  sl.registerLazySingleton(() => PayPayroll(sl()));
  sl.registerFactory(() => PayrollCubit(sl(), sl(), sl(), sl()));

  sl.registerLazySingleton(() => MonthlyClosingRemoteDataSource(sl()));
  sl.registerLazySingleton<MonthlyClosingRepository>(
    () => MonthlyClosingRepositoryImpl(sl()),
  );
  sl.registerLazySingleton(() => ListClosings(sl()));
  sl.registerLazySingleton(() => CloseMonth(sl()));
  sl.registerLazySingleton(() => ReopenMonth(sl()));
  sl.registerFactory(() => MonthlyClosingCubit(sl(), sl(), sl()));

  sl.registerLazySingleton(() => DocumentsRemoteDataSource(sl(), sl()));
  sl.registerLazySingleton<DocumentsRepository>(
    () => DocumentsRepositoryImpl(sl()),
  );
  sl.registerLazySingleton(() => ListTravelerDocuments(sl()));
  sl.registerLazySingleton(() => UploadTravelerDocument(sl()));
  sl.registerLazySingleton(() => CreateDocumentLink(sl()));
  sl.registerLazySingleton(() => DeleteTravelerDocument(sl()));
  sl.registerLazySingleton(() => DownloadTravelerDocument(sl()));
  sl.registerFactory(() => DocumentsCubit(sl(), sl(), sl(), sl(), sl()));

  sl.registerLazySingleton(() => ReportsRemoteDataSource(sl()));
  sl.registerLazySingleton<ReportsRepository>(
    () => ReportsRepositoryImpl(sl()),
  );
  sl.registerLazySingleton(() => LoadMonthlyReport(sl()));
  sl.registerFactory(() => ReportsCubit(sl()));

  sl.registerLazySingleton(() => AuditRemoteDataSource(sl()));
  sl.registerLazySingleton<AuditRepository>(() => AuditRepositoryImpl(sl()));
  sl.registerLazySingleton(() => ListAuditEntries(sl()));
  sl.registerFactory(() => AuditCubit(sl()));

  sl.registerLazySingleton(() => SettingsLocalDataSource(sl(), sl()));
  sl.registerLazySingleton<SettingsRepository>(
    () => SettingsRepositoryImpl(sl()),
  );
  sl.registerLazySingleton(() => LoadSystemSettings(sl()));
  sl.registerLazySingleton(() => ClearLocalCache(sl()));
  sl.registerFactory(() => SettingsCubit(sl(), sl()));

  sl.registerLazySingleton(() => DashboardRemoteDataSource(sl()));
  sl.registerLazySingleton<DashboardRepository>(
    () => DashboardRepositoryImpl(sl()),
  );
  sl.registerLazySingleton(() => LoadDashboardSummary(sl()));
  sl.registerFactory(() => DashboardCubit(sl()));
}
