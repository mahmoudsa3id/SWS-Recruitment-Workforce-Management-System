class PayrollRecord {
  const PayrollRecord({
    required this.id,
    required this.employeeName,
    required this.monthStart,
    required this.baseSalary,
    required this.commission,
    required this.deductions,
    required this.paidAmount,
    required this.status,
    this.bonus = 0,
    this.overtimeHours = 0,
    this.overtimeRate = 0,
  });
  final String id, employeeName, status;
  final DateTime monthStart;
  final double baseSalary,
      commission,
      deductions,
      paidAmount,
      bonus,
      overtimeHours,
      overtimeRate;
  double get overtimeAmount => overtimeHours * overtimeRate;
  double get earned =>
      (baseSalary + commission + bonus + overtimeAmount - deductions)
          .clamp(0, double.infinity)
          .toDouble();
  double get outstanding =>
      (earned - paidAmount).clamp(0, double.infinity).toDouble();
}
