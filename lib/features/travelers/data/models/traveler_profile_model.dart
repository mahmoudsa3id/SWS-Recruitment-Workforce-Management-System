import '../../domain/entities/traveler_profile.dart';
import 'traveler_model.dart';
import 'traveler_payment_model.dart';
import 'traveler_document_summary_model.dart';

/// Maps the aggregate returned by several data sources into one domain profile.
class TravelerProfileModel {
  static TravelerProfile fromData({
    required Map<String, dynamic> traveler,
    required List<Map<String, dynamic>> movements,
    required List<Map<String, dynamic>> documents,
    bool isCachedSnapshot = false,
  }) => TravelerProfile(
    traveler: TravelerModel.fromMap(traveler),
    payments: movements
        .map(TravelerPaymentModel.fromMap)
        .toList(growable: false),
    documents: documents
        .map(TravelerDocumentSummaryModel.fromMap)
        .toList(growable: false),
    isCachedSnapshot: isCachedSnapshot,
  );
}
