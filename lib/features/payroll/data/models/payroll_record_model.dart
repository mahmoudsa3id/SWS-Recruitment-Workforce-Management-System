import '../../domain/entities/payroll_record.dart';

class PayrollRecordModel extends PayrollRecord {
  const PayrollRecordModel({required super.id, required super.employeeName, required super.monthStart, required super.baseSalary, required super.commission, required super.deductions, required super.paidAmount, required super.status, super.bonus = 0, super.overtimeHours = 0, super.overtimeRate = 0});
  factory PayrollRecordModel.fromMap(Map<String, dynamic> m) => PayrollRecordModel(
    id: '${m['id'] ?? ''}', employeeName: '${m['employee_name'] ?? ''}',
    monthStart: DateTime.tryParse('${m['month_start'] ?? ''}') ?? DateTime.fromMillisecondsSinceEpoch(0),
    baseSalary: _n(m['base_salary']), commission: _n(m['commission']), deductions: _n(m['deductions']),
    paidAmount: _n(m['paid_amount']), status: '${m['status'] ?? 'open'}', bonus: _n(m['bonus']),
    overtimeHours: _n(m['overtime_hours']), overtimeRate: _n(m['overtime_rate']),
  );
  static double _n(dynamic v) { final parsed = v is num ? v.toDouble() : double.tryParse('$v') ?? 0; return parsed.isFinite ? parsed : 0; }
}
