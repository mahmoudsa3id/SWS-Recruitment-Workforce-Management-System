import 'package:flutter_test/flutter_test.dart';
import 'package:sws_staff/main.dart';

void main() {
  testWidgets('shows setup guidance when no Supabase configuration is supplied', (tester) async {
    await tester.pumpWidget(const SWSApp(configured: false));
    expect(find.text('إعداد اتصال Supabase'), findsOneWidget);
    expect(find.textContaining('SUPABASE_URL'), findsOneWidget);
  });
}
