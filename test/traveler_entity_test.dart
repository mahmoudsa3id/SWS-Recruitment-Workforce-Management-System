import 'package:flutter_test/flutter_test.dart';
import 'package:sws_staff/features/travelers/domain/entities/traveler.dart';
import 'package:sws_staff/features/travelers/domain/entities/traveler_payment.dart';
import 'package:sws_staff/features/travelers/domain/entities/traveler_profile.dart';

void main() {
  group('Traveler domain invariants', () {
    test('remaining agreement is agreement minus received amount', () {
      final traveler = Traveler(id: 't1', fullName: 'Test', phone: '010', agreementTotal: 1000, paidAmount: 300, createdAt: DateTime(2026));
      expect(traveler.remaining, 700);
    });
    test('remaining never becomes negative for overpaid agreement', () {
      final traveler = Traveler(id: 't1', fullName: 'Test', phone: '010', agreementTotal: 1000, paidAmount: 1200, createdAt: DateTime(2026));
      expect(traveler.remaining, 0);
    });
    test('profile net total subtracts reversals and ignores unrelated movements', () {
      final traveler = Traveler(id: 't1', fullName: 'Test', phone: '010', agreementTotal: 1500, paidAmount: 1000, createdAt: DateTime(2026));
      final profile = TravelerProfile(traveler: traveler, payments: [
        TravelerPayment(id:'1', travelerId:'t1', amount:1000, method:'cash', paidAt:DateTime(2026), receiptNo:'R1', status:'posted', direction:'credit', movementType:'traveler_collection'),
        TravelerPayment(id:'2', travelerId:'t1', amount:200, method:'cash', paidAt:DateTime(2026), receiptNo:'R2', status:'reversed', direction:'credit', movementType:'traveler_collection'),
        TravelerPayment(id:'3', travelerId:'t1', amount:200, method:'cash', paidAt:DateTime(2026), receiptNo:'R3', status:'posted', direction:'debit', movementType:'reversal', reversesMovementId:'2'),
        TravelerPayment(id:'4', travelerId:'t1', amount:500, method:'cash', paidAt:DateTime(2026), receiptNo:'R4', status:'posted', direction:'credit', movementType:'general_revenue'),
      ], documents: const []);
      expect(profile.netPaid, 1000);
      expect(profile.remaining, 500);
    });
  });
}
