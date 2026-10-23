class TravelerPayment {
  const TravelerPayment({required this.id, required this.travelerId, required this.amount, required this.method, required this.paidAt, required this.receiptNo, required this.status, required this.direction, required this.movementType, this.note, this.reversesMovementId});
  final String id, travelerId, method, receiptNo, status, direction, movementType;
  final double amount;
  final DateTime paidAt;
  final String? note, reversesMovementId;
  bool get isPosted => status == 'posted';
  bool get isTravelerCollection => movementType == 'traveler_collection';
}
