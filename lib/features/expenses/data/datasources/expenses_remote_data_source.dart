import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/utils/id_generator.dart';
import '../../../../core/month_scope/accounting_month_scope.dart';

class ExpensesRemoteDataSource {
  ExpensesRemoteDataSource(this.client);
  final SupabaseClient client;
  Future<List<Map<String, dynamic>>> list() async {
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
          .from('office_expenses')
          .select(
            'id,movement_id,category,description,created_at,financial_movements(receipt_no,amount,payment_method,status)',
          )
          .gte('created_at', from.toIso8601String())
          .lt('created_at', to.toIso8601String())
          .order('created_at', ascending: false)
          .limit(1000),
    );
  }

  Future<String> create({
    required double amount,
    required String method,
    required String category,
    required String description,
  }) async =>
      '${await client.rpc('sws_record_office_expense', params: {'p_amount': amount, 'p_payment_method': method, 'p_category': category.trim(), 'p_description': description.trim(), 'p_idempotency_key': IdGenerator.uuidV4()})}';
  Future<void> update({
    required String expenseId,
    required double amount,
    required String method,
    required String category,
    required String description,
    required String reason,
  }) async {
    await client.rpc(
      'sws_update_office_expense_full',
      params: {
        'p_expense_id': expenseId,
        'p_amount': amount,
        'p_payment_method': method,
        'p_category': category.trim(),
        'p_description': description.trim(),
        'p_reason': reason.trim(),
      },
    );
  }

  Future<void> delete({
    required String expenseId,
    required String reason,
  }) async {
    await client.rpc(
      'sws_delete_office_expense',
      params: {'p_expense_id': expenseId, 'p_reason': reason.trim()},
    );
  }
}
