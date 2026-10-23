import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/utils/id_generator.dart';
import '../../../../core/month_scope/accounting_month_scope.dart';
class FinanceRemoteDataSource {
  FinanceRemoteDataSource(this.client); final SupabaseClient client;
  Future<List<Map<String, dynamic>>> list({DateTime? from, DateTime? to, String? type}) async {
    final selectedMonth = AccountingMonthScope.start;
    from ??= DateTime.utc(selectedMonth.year, selectedMonth.month, 1).subtract(const Duration(hours: 3));
    to ??= DateTime.utc(selectedMonth.year, selectedMonth.month + 1, 1).subtract(const Duration(hours: 3));
    var query = client.from('financial_movements').select(
      'id,receipt_no,movement_type,direction,amount,payment_method,note,status,created_at,traveler_id,reverses_movement_id,travelers(full_name)',
    );
    if (from != null) query = query.gte('created_at', from.toUtc().toIso8601String());
    if (to != null) query = query.lt('created_at', to.toUtc().toIso8601String());
    if (type != null && type.trim().isNotEmpty) query = query.eq('movement_type', type.trim());
    final rows = await query.order('created_at', ascending: false).limit(2000);
    return List<Map<String, dynamic>>.from(rows);
  }
  Future<String> generalRevenue({required double amount, required String method, required String note}) async {
    final id = '${await client.rpc('sws_record_general_revenue', params: {'p_amount': amount, 'p_payment_method': method, 'p_note': note.trim(), 'p_idempotency_key': IdGenerator.uuidV4()})}';
    final row = Map<String,dynamic>.from(await client.from('financial_movements').select('receipt_no').eq('id', id).single());
    return '${row['receipt_no'] ?? id}';
  }
  Future<void> deleteMovement({required String id, required String reason}) async { await client.rpc('sws_delete_financial_movement', params: {'p_movement_id': id, 'p_reason': reason.trim()}); }
  Future<void> updateNote({required String id,required String note,required String reason}) async { await client.rpc('sws_update_movement_note',params:{'p_movement_id':id,'p_note':note.trim(),'p_reason':reason.trim()}); }
}
