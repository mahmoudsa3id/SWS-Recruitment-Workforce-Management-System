import '../../domain/entities/office_expense.dart';

class OfficeExpenseModel extends OfficeExpense {
  const OfficeExpenseModel({
    required super.id,
    required super.movementId,
    required super.category,
    required super.description,
    required super.amount,
    required super.method,
    required super.receiptNo,
    required super.status,
    required super.createdAt,
  });
  factory OfficeExpenseModel.fromMap(Map<String, dynamic> m) {
    final x = m['financial_movements'];
    final f = x is Map ? x : <String, dynamic>{};
    return OfficeExpenseModel(
      id: '${m['id'] ?? ''}',
      movementId: '${m['movement_id'] ?? ''}',
      category: '${m['category'] ?? ''}',
      description: '${m['description'] ?? ''}',
      amount: _n(f['amount']),
      method: '${f['payment_method'] ?? 'cash'}',
      receiptNo: '${f['receipt_no'] ?? ''}',
      status: '${f['status'] ?? 'posted'}',
      createdAt:
          DateTime.tryParse('${m['created_at'] ?? ''}') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
  static double _n(dynamic v) {
    final parsed = v is num ? v.toDouble() : double.tryParse('$v') ?? 0;
    return parsed.isFinite ? parsed : 0;
  }
}
