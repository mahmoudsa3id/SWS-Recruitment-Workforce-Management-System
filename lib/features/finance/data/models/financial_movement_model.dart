import '../../domain/entities/financial_movement.dart';
class FinancialMovementModel extends FinancialMovement {
  const FinancialMovementModel({required super.id, required super.receiptNo, required super.type, required super.direction, required super.amount, required super.paymentMethod, required super.status, required super.createdAt, super.travelerId, super.travelerName, super.note, super.reversesMovementId});
  factory FinancialMovementModel.fromMap(Map<String, dynamic> map) {
    final traveler = map['travelers'];
    return FinancialMovementModel(
      id: '${map['id'] ?? ''}', receiptNo: '${map['receipt_no'] ?? ''}', type: '${map['movement_type'] ?? 'correction'}',
      direction: '${map['direction'] ?? 'debit'}', amount: _number(map['amount']), paymentMethod: '${map['payment_method'] ?? 'cash'}',
      status: '${map['status'] ?? 'posted'}', createdAt: DateTime.tryParse('${map['created_at'] ?? ''}') ?? DateTime.fromMillisecondsSinceEpoch(0),
      travelerId: map['traveler_id']?.toString(), travelerName: traveler is Map ? traveler['full_name']?.toString() : null,
      note: map['note']?.toString(), reversesMovementId: map['reverses_movement_id']?.toString());
  }
  static double _number(dynamic value) { final parsed = value is num ? value.toDouble() : double.tryParse('${value ?? ''}') ?? 0; return parsed.isFinite ? parsed : 0; }
}
