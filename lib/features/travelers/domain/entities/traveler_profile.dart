import 'traveler.dart';
import 'traveler_payment.dart';
import 'traveler_document_summary.dart';

class TravelerProfile {
  const TravelerProfile({required this.traveler, required this.payments, required this.documents, this.isCachedSnapshot = false});
  final Traveler traveler;
  final List<TravelerPayment> payments;
  final List<TravelerDocumentSummary> documents;
  final bool isCachedSnapshot;
  double get netPaid {
    final collected = payments.where((p) => p.status != 'void' && p.direction == 'credit' && p.isTravelerCollection).fold<double>(0, (sum, payment) => sum + payment.amount);
    final reversed = payments.where((p) => p.isPosted && p.direction == 'debit' && p.movementType == 'reversal' && p.reversesMovementId != null).fold<double>(0, (sum, payment) => sum + payment.amount);
    return (collected - reversed).clamp(0, double.infinity).toDouble();
  }
  double get remaining => (traveler.agreementTotal - netPaid).clamp(0, double.infinity).toDouble();
}
