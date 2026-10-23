import 'package:flutter_test/flutter_test.dart';
import 'package:sws_staff/core/printing/traveler_summary_pdf.dart';
import 'package:sws_staff/features/travelers/domain/entities/traveler.dart';
import 'package:sws_staff/features/travelers/domain/entities/traveler_profile.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('builds a traveler summary PDF with Latin file identifiers', () async {
    final profile = TravelerProfile(
      traveler: Traveler(
        id: 'traveler-1',
        fileNo: 'SWS-123',
        fullName: 'مسافر',
        phone: '01012345678',
        agreementTotal: 1000,
        paidAmount: 0,
        createdAt: DateTime(2026, 10, 17),
      ),
      payments: [],
      documents: [],
    );

    final bytes = await TravelerSummaryPdf.build(profile);

    expect(bytes, isNotEmpty);
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
  });
}
