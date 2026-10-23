import '../../domain/entities/traveler_payment.dart';

class TravelerPaymentModel extends TravelerPayment {
  const TravelerPaymentModel({
    required super.id,
    required super.travelerId,
    required super.amount,
    required super.method,
    required super.paidAt,
    required super.receiptNo,
    required super.status,
    required super.direction,
    required super.movementType,
    super.note,
    super.reversesMovementId,
  });
  factory TravelerPaymentModel.fromMap(Map<String, dynamic> map) =>
      TravelerPaymentModel(
        id: '${map['id'] ?? ''}',
        travelerId: '${map['traveler_id'] ?? ''}',
        amount: _num(map['amount']),
        method: '${map['payment_method'] ?? 'cash'}',
        paidAt:
            DateTime.tryParse('${map['created_at'] ?? map['paid_at'] ?? ''}') ??
            DateTime.fromMillisecondsSinceEpoch(0),
        receiptNo: '${map['receipt_no'] ?? ''}',
        status: '${map['status'] ?? 'posted'}',
        direction: '${map['direction'] ?? 'credit'}',
        movementType: '${map['movement_type'] ?? 'traveler_collection'}',
        note: map['note']?.toString(),
        reversesMovementId: map['reverses_movement_id']?.toString(),
      );
  static double _num(dynamic value) {
    final parsed = value is num
        ? value.toDouble()
        : double.tryParse('${value ?? ''}') ?? 0;
    return parsed.isFinite ? parsed : 0;
  }
}
