import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/di/injection.dart';

class FinancialRequestsPage extends StatefulWidget {
  const FinancialRequestsPage({super.key});
  @override
  State<FinancialRequestsPage> createState() => _FinancialRequestsPageState();
}

class _FinancialRequestsPageState extends State<FinancialRequestsPage> {
  late Future<List<Map<String, dynamic>>> _requests;
  bool _working = false;

  @override
  void initState() {
    super.initState();
    _requests = _load();
  }

  Future<List<Map<String, dynamic>>> _load() async {
    final result = await sl<SupabaseClient>().rpc(
      'sws_list_financial_requests',
    );
    if (result is! List) {
      throw const FormatException('استجابة طلبات العمليات المالية غير صحيحة.');
    }
    return result
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList(growable: false);
  }

  void _refresh() => setState(() => _requests = _load());

  Future<void> _review(Map<String, dynamic> request, String decision) async {
    final note = TextEditingController();
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          decision == 'approve' ? 'اعتماد الطلب المالي' : 'رفض الطلب المالي',
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('المسافر: ${request['traveler_name'] ?? '—'}'),
            Text('المبلغ: ${_money(request['amount'])} ج.م'),
            const SizedBox(height: 12),
            TextField(
              controller: note,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: decision == 'reject'
                    ? 'سبب الرفض (اختياري)'
                    : 'ملاحظة المراجعة (اختياري)',
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('رجوع'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(
              decision == 'approve' ? 'اعتماد وتنفيذ' : 'تأكيد الرفض',
            ),
          ),
        ],
      ),
    );
    if (accepted != true || !mounted) return;
    setState(() => _working = true);
    try {
      await sl<SupabaseClient>().rpc(
        'sws_review_financial_request',
        params: {
          'p_request_id': request['id'],
          'p_decision': decision,
          'p_review_note': note.text.trim(),
        },
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            decision == 'approve'
                ? 'تم اعتماد الطلب وتسجيل الدفعة وتحديث الرصيد.'
                : 'تم رفض الطلب، ولم يتغير الرصيد.',
          ),
        ),
      );
      _refresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('تعذر معالجة الطلب: $e')));
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  double _num(dynamic value) =>
      value is num ? value.toDouble() : double.tryParse('$value') ?? 0;
  String _money(dynamic value) => _num(value).toStringAsFixed(2);
  String _method(dynamic value) => switch ('$value') {
    'cash' => 'نقدي',
    'instapay' => 'إنستاباي',
    'bank_transfer' => 'تحويل بنكي',
    'wallet' => 'محفظة إلكترونية',
    _ => 'أخرى',
  };
  String _status(dynamic value) => switch ('$value') {
    'approved' => 'تمت الموافقة',
    'rejected' => 'مرفوض',
    _ => 'بانتظار المراجعة',
  };
  Color _statusColor(dynamic value) => switch ('$value') {
    'approved' => Colors.green,
    'rejected' => Colors.red,
    _ => Colors.orange.shade800,
  };

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('طلبات العمليات المالية'),
      actions: [
        IconButton(
          onPressed: _refresh,
          tooltip: 'تحديث',
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: FutureBuilder<List<Map<String, dynamic>>>(
      future: _requests,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('تعذر تحميل الطلبات المالية.'),
                  const SizedBox(height: 8),
                  Text(
                    '${snapshot.error}',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: _refresh,
                    child: const Text('إعادة المحاولة'),
                  ),
                ],
              ),
            ),
          );
        }
        final items = snapshot.data ?? const <Map<String, dynamic>>[];
        if (items.isEmpty) {
          return const Center(child: Text('لا توجد طلبات مالية حتى الآن.'));
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final r = items[index];
            final pending = r['status'] == 'pending';
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.receipt_long_outlined, size: 28),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${r['traveler_name'] ?? 'مسافر'}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                ),
                              ),
                              Text('رقم الملف: ${r['file_no'] ?? '—'}'),
                              Text('مقدم الطلب: ${r['requester_name'] ?? '—'}'),
                            ],
                          ),
                        ),
                        Text(
                          '${_money(r['amount'])} ج.م',
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 17,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        Chip(
                          label: Text(_status(r['status'])),
                          labelStyle: TextStyle(
                            color: _statusColor(r['status']),
                          ),
                        ),
                        Chip(label: Text(_method(r['payment_method']))),
                        Chip(label: Text('طلب دفعة')),
                      ],
                    ),
                    if ('${r['note'] ?? ''}'.trim().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text('البيان: ${r['note']}'),
                      ),
                    if ('${r['review_note'] ?? ''}'.trim().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text('ملاحظة المراجعة: ${r['review_note']}'),
                      ),
                    if (pending) ...[
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 10,
                        runSpacing: 8,
                        children: [
                          FilledButton.icon(
                            onPressed: _working
                                ? null
                                : () => _review(r, 'approve'),
                            icon: const Icon(Icons.check_circle_outline),
                            label: const Text('موافقة وتنفيذ الدفعة'),
                          ),
                          OutlinedButton.icon(
                            onPressed: _working
                                ? null
                                : () => _review(r, 'reject'),
                            icon: const Icon(Icons.cancel_outlined),
                            label: const Text('رفض'),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    ),
  );
}
