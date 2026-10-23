class DashboardTrendPoint {
  const DashboardTrendPoint({
    required this.monthStart,
    required this.collections,
    required this.generalRevenue,
    required this.officeExpenses,
    required this.payrollPaid,
    required this.totalCredits,
    required this.totalDebits,
  });

  final DateTime monthStart;
  final double collections;
  final double generalRevenue;
  final double officeExpenses;
  final double payrollPaid;
  final double totalCredits;
  final double totalDebits;

  double get income => totalCredits;
  double get spending => totalDebits;
}

class DashboardSummary {
  const DashboardSummary({
    required this.travelerCount,
    required this.employeeCount,
    required this.totalCollections,
    required this.generalRevenue,
    required this.officeExpenses,
    required this.payrollPaid,
    required this.cashBalance,
    this.totalTravelersCount = 0,
    this.travelerAgreementTotal = 0,
    this.travelerPaidTotal = 0,
    this.travelerRemainingTotal = 0,
    this.travelersFullyPaid = 0,
    this.travelersWithBalance = 0,
    this.stageNew = 0,
    this.stageSubmitted = 0,
    this.stageInspected = 0,
    this.stageVisa = 0,
    this.stageFlight = 0,
    this.monthlyTrend = const [],
  });

  /// Travelers created in the currently selected accounting month.
  final int travelerCount;
  final int employeeCount;

  /// Selected-month financial movements.
  final double totalCollections;
  final double generalRevenue;
  final double officeExpenses;
  final double payrollPaid;
  final double cashBalance;

  /// All-time balances for non-archived travelers.
  final int totalTravelersCount;
  final double travelerAgreementTotal;
  final double travelerPaidTotal;
  final double travelerRemainingTotal;
  final int travelersFullyPaid;
  final int travelersWithBalance;

  /// Mutually exclusive stage counts, derived from the furthest completed stage.
  final int stageNew;
  final int stageSubmitted;
  final int stageInspected;
  final int stageVisa;
  final int stageFlight;

  /// Last six months ending at the selected accounting month.
  final List<DashboardTrendPoint> monthlyTrend;

  int get totalStageCount =>
      stageNew + stageSubmitted + stageInspected + stageVisa + stageFlight;
}
