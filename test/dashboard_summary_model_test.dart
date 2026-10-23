import 'package:flutter_test/flutter_test.dart';
import 'package:sws_staff/features/dashboard/data/models/dashboard_summary_model.dart';

void main() {
  test('dashboard parses all-time traveler balance and analytics', () {
    final summary = DashboardSummaryModel.fromMap({
      'traveler_count': 2,
      'employee_count': 3,
      'total_collections': 100,
      'general_revenue': 25,
      'office_expenses': 10,
      'payroll_paid': 40,
      'cash_balance': 75,
      'total_travelers_count': 5,
      'traveler_agreement_total': 1000,
      'traveler_paid_total': 650,
      'traveler_remaining_total': 350,
      'travelers_fully_paid': 2,
      'travelers_with_balance': 3,
      'traveler_stages': {
        'new': 1,
        'submitted': 1,
        'inspected': 1,
        'visa': 1,
        'flight': 1,
      },
      'monthly_trend': [
        {
          'month_start': '2026-10-01',
          'collections': 100,
          'general_revenue': 25,
          'office_expenses': 10,
          'payroll_paid': 40,
          'total_credits': 125,
          'total_debits': 50,
        },
      ],
    });

    expect(summary.travelerAgreementTotal, 1000);
    expect(summary.travelerPaidTotal, 650);
    expect(summary.travelerRemainingTotal, 350);
    expect(summary.travelersWithBalance, 3);
    expect(summary.monthlyTrend.single.income, 125);
    expect(summary.monthlyTrend.single.spending, 50);
  });
}
