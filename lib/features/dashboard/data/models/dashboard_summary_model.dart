import '../../domain/entities/dashboard_summary.dart';

class DashboardSummaryModel extends DashboardSummary {
  const DashboardSummaryModel({
    required super.travelerCount,
    required super.employeeCount,
    required super.totalCollections,
    required super.generalRevenue,
    required super.officeExpenses,
    required super.payrollPaid,
    required super.cashBalance,
    super.totalTravelersCount,
    super.travelerAgreementTotal,
    super.travelerPaidTotal,
    super.travelerRemainingTotal,
    super.travelersFullyPaid,
    super.travelersWithBalance,
    super.stageNew,
    super.stageSubmitted,
    super.stageInspected,
    super.stageVisa,
    super.stageFlight,
    super.monthlyTrend,
  });

  factory DashboardSummaryModel.fromMap(Map<String, dynamic> map) {
    final stages = _map(map['traveler_stages']);
    final trendData = map['monthly_trend'];
    final trend = trendData is List
        ? trendData.whereType<Map>().map((item) {
            final row = Map<String, dynamic>.from(item);
            return DashboardTrendPoint(
              monthStart: DateTime.tryParse('${row['month_start'] ?? ''}') ??
                  DateTime(2000),
              collections: _n(row['collections']),
              generalRevenue: _n(row['general_revenue']),
              officeExpenses: _n(row['office_expenses']),
              payrollPaid: _n(row['payroll_paid']),
              totalCredits: _n(row['total_credits']),
              totalDebits: _n(row['total_debits']),
            );
          }).toList(growable: false)
        : const <DashboardTrendPoint>[];

    return DashboardSummaryModel(
      travelerCount: _i(map['traveler_count']),
      employeeCount: _i(map['employee_count']),
      totalCollections: _n(map['total_collections']),
      generalRevenue: _n(map['general_revenue']),
      officeExpenses: _n(map['office_expenses']),
      payrollPaid: _n(map['payroll_paid']),
      cashBalance: _n(map['cash_balance']),
      totalTravelersCount: _i(map['total_travelers_count']),
      travelerAgreementTotal: _n(map['traveler_agreement_total']),
      travelerPaidTotal: _n(map['traveler_paid_total']),
      travelerRemainingTotal: _n(map['traveler_remaining_total']),
      travelersFullyPaid: _i(map['travelers_fully_paid']),
      travelersWithBalance: _i(map['travelers_with_balance']),
      stageNew: _i(stages['new']),
      stageSubmitted: _i(stages['submitted']),
      stageInspected: _i(stages['inspected']),
      stageVisa: _i(stages['visa']),
      stageFlight: _i(stages['flight']),
      monthlyTrend: trend,
    );
  }

  static Map<String, dynamic> _map(dynamic value) =>
      value is Map ? Map<String, dynamic>.from(value) : const {};

  static int _i(dynamic value) =>
      value is num ? value.toInt() : int.tryParse('$value') ?? 0;

  static double _n(dynamic value) {
    final parsed =
        value is num ? value.toDouble() : double.tryParse('${value ?? ''}') ?? 0;
    return parsed.isFinite ? parsed : 0;
  }
}
