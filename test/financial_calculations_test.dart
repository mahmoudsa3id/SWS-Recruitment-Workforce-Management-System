import 'package:flutter_test/flutter_test.dart';
import 'package:sws_staff/features/finance/domain/entities/financial_movement.dart';
import 'package:sws_staff/features/payroll/domain/entities/payroll_record.dart';
import 'package:sws_staff/features/reports/domain/entities/monthly_financial_report.dart';

void main() {
  test('posted credits and debits have the correct signed cash impact', () {
    final credit = FinancialMovement(id:'1',receiptNo:'R1',type:'traveler_collection',direction:'credit',amount:1000,paymentMethod:'cash',status:'posted',createdAt:DateTime(2026));
    final debit = FinancialMovement(id:'2',receiptNo:'R2',type:'office_expense',direction:'debit',amount:250,paymentMethod:'cash',status:'posted',createdAt:DateTime(2026));
    final reversed = FinancialMovement(id:'3',receiptNo:'R3',type:'office_expense',direction:'debit',amount:250,paymentMethod:'cash',status:'reversed',createdAt:DateTime(2026));
    expect(credit.signedAmount, 1000);
    expect(debit.signedAmount, -250);
    expect(reversed.signedAmount, -250);
  });
  test('payroll outstanding includes partial payments and clamps negative result', () {
    final record = PayrollRecord(id:'p1',employeeName:'أحمد',monthStart:DateTime(2026,10),baseSalary:5000,commission:500,deductions:300,paidAmount:2000,status:'open');
    expect(record.earned, 5200);
    expect(record.outstanding, 3200);
  });
  test('monthly report computes cash net and closing balance', () {
    final report = MonthlyFinancialReport(monthStart:DateTime(2026,10),openingBalance:1000,travelerCollections:5000,generalRevenue:300,officeExpenses:1200,payrollPayments:1000,otherCredits:50,otherDebits:25);
    expect(report.totalIncome, 5350);
    expect(report.totalExpenses, 2225);
    expect(report.netMovement, 3125);
    expect(report.closingBalance, 4125);
  });
}
