import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/month_scope/accounting_month_scope.dart';

class AuditRemoteDataSource {
  AuditRemoteDataSource(this.client);
  final SupabaseClient client;
  Future<List<Map<String, dynamic>>> list(int limit) async {
    final m = AccountingMonthScope.start;
    final from = DateTime.utc(
      m.year,
      m.month,
      1,
    ).subtract(const Duration(hours: 3));
    final to = DateTime.utc(
      m.year,
      m.month + 1,
      1,
    ).subtract(const Duration(hours: 3));
    return List<Map<String, dynamic>>.from(
      await client
          .from('audit_log')
          .select()
          .gte('created_at', from.toIso8601String())
          .lt('created_at', to.toIso8601String())
          .order('created_at', ascending: false)
          .limit(limit.clamp(1, 1000).toInt()),
    );
  }
}
