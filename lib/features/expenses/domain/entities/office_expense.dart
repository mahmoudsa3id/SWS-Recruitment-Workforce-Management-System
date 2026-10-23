class OfficeExpense {
  const OfficeExpense({
    required this.id,
    required this.movementId,
    required this.category,
    required this.description,
    required this.amount,
    required this.method,
    required this.receiptNo,
    required this.status,
    required this.createdAt,
  });
  final String id, movementId, category, description, method, receiptNo, status;
  final double amount;
  final DateTime createdAt;
}
