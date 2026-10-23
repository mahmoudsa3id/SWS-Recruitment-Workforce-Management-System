import 'package:supabase_flutter/supabase_flutter.dart';

class MonthlyClosingRemoteDataSource {
  MonthlyClosingRemoteDataSource(this.client);
  final SupabaseClient client;
  Future<List<Map<String, dynamic>>> list() async =>
      List<Map<String, dynamic>>.from(
        await client
            .from('monthly_closings')
            .select()
            .order('month_start', ascending: false)
            .limit(120),
      );
  Future<String> close(DateTime month, String note) async =>
      '${await client.rpc('sws_close_month', params: {'p_month': '${month.year}-${month.month.toString().padLeft(2, '0')}-01', 'p_note': note})}';
  Future<String> reopen(DateTime month, String reason) async =>
      '${await client.rpc('sws_reopen_month', params: {'p_month': '${month.year}-${month.month.toString().padLeft(2, '0')}-01', 'p_reason': reason.trim()})}';
}
