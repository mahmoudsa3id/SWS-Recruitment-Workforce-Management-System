import '../../domain/entities/monthly_financial_report.dart';

class MonthlyFinancialReportModel extends MonthlyFinancialReport {
  const MonthlyFinancialReportModel({
    required super.monthStart,
    required super.openingBalance,
    required super.travelerCollections,
    required super.generalRevenue,
    required super.officeExpenses,
    required super.payrollPayments,
    required super.otherCredits,
    required super.otherDebits,
  });
}
