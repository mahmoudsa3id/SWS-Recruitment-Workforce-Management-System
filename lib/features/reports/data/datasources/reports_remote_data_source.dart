import 'package:supabase_flutter/supabase_flutter.dart';

class ReportsRemoteDataSource {
  ReportsRemoteDataSource(this.client);
  final SupabaseClient client;

  Future<Map<String, dynamic>> fetch(DateTime month) async {
    final start = DateTime(month.year, month.month, 1);
    final result = await client.rpc(
      'sws_monthly_financial_report',
      params: {'p_month_start': '${start.year}-${start.month.toString().padLeft(2, '0')}-01'},
    );
    if (result is! Map) throw const FormatException('Invalid monthly report response');
    return Map<String, dynamic>.from(result);
  }
}
