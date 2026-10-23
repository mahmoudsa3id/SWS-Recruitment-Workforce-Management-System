class FinancialMovement {
  const FinancialMovement({required this.id, required this.receiptNo, required this.type, required this.direction, required this.amount, required this.paymentMethod, required this.status, required this.createdAt, this.travelerId, this.travelerName, this.note, this.reversesMovementId});
  final String id, receiptNo, type, direction, paymentMethod, status;
  final double amount;
  final DateTime createdAt;
  final String? travelerId, travelerName, note, reversesMovementId;
  bool get isCredit => direction == 'credit';
  bool get isPosted => status == 'posted';
  bool get isLedgerEvent => status == 'posted' || status == 'reversed';
  double get signedAmount => (status == 'posted' || status == 'reversed') ? (isCredit ? amount : -amount) : 0;
}
