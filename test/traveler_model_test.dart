import 'package:flutter_test/flutter_test.dart';
import 'package:sws_staff/features/travelers/data/models/traveler_model.dart';

void main() {
  test('TravelerModel converts database values safely into domain values', () {
    final model = TravelerModel.fromMap({'id':'t1','full_name':'أحمد','phone':'010','agreement_total':'1200.75','paid_amount':null,'created_at':'invalid','stage_submitted':'true','stage_inspected':true});
    expect(model.id, 't1');
    expect(model.agreementTotal, 1200.75);
    expect(model.paidAmount, 0);
    expect(model.createdAt, DateTime.fromMillisecondsSinceEpoch(0));
    expect(model.submitted, isFalse);
    expect(model.inspected, isTrue);
  });
  test('TravelerModel normalizes non-finite number values', () {
    final model = TravelerModel.fromMap({'agreement_total':double.infinity,'paid_amount':'NaN'});
    expect(model.agreementTotal, 0);
    expect(model.paidAmount, 0);
  });
}
