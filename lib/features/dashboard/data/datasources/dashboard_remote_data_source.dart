import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/month_scope/accounting_month_scope.dart'; class DashboardRemoteDataSource {
  DashboardRemoteDataSource(this.client);
  final SupabaseClient client;
  Future<Map<String,dynamic>> fetchSummary() async {
    final month = AccountingMonthScope.start;
    final result = await client.rpc('sws_get_monthly_dashboard_summary', params: {'p_month_start': '${month.year}-${month.month.toString().padLeft(2, '0')}-01'});
    if (result is! Map) throw const FormatException('Invalid dashboard summary response');
    return Map<String,dynamic>.from(result);
  }
}
