import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/di/injection.dart';
import '../../../core/printing/receipt_printer.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../domain/entities/financial_movement.dart';
import 'cubit/finance_cubit.dart';
import '../../../core/widgets/app_loading_skeleton.dart';

class FinancialMovementsPage extends StatelessWidget {
  const FinancialMovementsPage({super.key});
  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => sl<FinanceCubit>()..load(),
    child: const _FinanceView(),
  );
}

class _FinanceView extends StatelessWidget {
  const _FinanceView();

  Future<void> _addRevenue(BuildContext context) async {
    final amount = TextEditingController();
    final note = TextEditingController();
    var method = 'cash';
    final form = GlobalKey<FormState>();
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialog) => AlertDialog(
          title: const Text('تسجيل إيراد عام'),
          content: SizedBox(
            width: 420,
            child: Form(
              key: form,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: amount,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'المبلغ بالجنيه *',
                    ),
                    validator: (v) {
                      final n = double.tryParse(v ?? '');
                      return n == null || !n.isFinite || n <= 0
                          ? 'أدخل مبلغًا أكبر من صفر'
                          : null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: note,
                    decoration: const InputDecoration(labelText: 'البيان *'),
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'البيان مطلوب' : null,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: method,
                    decoration: const InputDecoration(labelText: 'طريقة الدفع'),
                    items: const [
                      DropdownMenuItem(value: 'cash', child: Text('نقدي')),
                      DropdownMenuItem(
                        value: 'instapay',
                        child: Text('إنستاباي'),
                      ),
                      DropdownMenuItem(
                        value: 'bank_transfer',
                        child: Text('تحويل بنكي'),
                      ),
                      DropdownMenuItem(
                        value: 'wallet',
                        child: Text('محفظة إلكترونية'),
                      ),
                      DropdownMenuItem(value: 'other', child: Text('أخرى')),
                    ],
                    onChanged: (v) => setDialog(() => method = v ?? 'cash'),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () {
                if (form.currentState?.validate() == true)
                  Navigator.pop(dialogContext, true);
              },
              child: const Text('تسجيل الإيراد'),
            ),
          ],
        ),
      ),
    );
    if (accepted != true || !context.mounted) return;
    final cubit = context.read<FinanceCubit>();
    final error = await cubit.addRevenue(
      amount: double.parse(amount.text),
      method: method,
      note: note.text,
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(error ?? 'تم تسجيل الإيراد.')));
    if (error == null) {
      await cubit.load();
      final receiptNo = cubit.lastReceiptNo;
      if (receiptNo != null && context.mounted) {
        await ReceiptPrinter.printTravelerReceipt(
          receiptNo: receiptNo,
          travelerName: 'إيراد عام',
          phone: '—',
          amount: double.parse(amount.text),
          method: method,
          date: DateTime.now(),
          status: 'posted',
          note: note.text,
          partyLabel: 'الطرف',
        );
      }
    }
  }

  Future<void> _deleteMovement(
    BuildContext context,
    FinancialMovement item,
  ) async {
    final reason = TextEditingController();
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('حذف الحركة المالية نهائيًا'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'سيتم حذف الحركة (${item.receiptNo}) من سجل الخزنة، ولن تُنشأ حركة عكسية. سيؤثر ذلك على الرصيد والتقارير، وسيُحتفظ بصورة في سجل المراجعة.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reason,
              minLines: 2,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'سبب الحذف *'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('حذف نهائي'),
          ),
        ],
      ),
    );
    if (accepted != true || !context.mounted) return;
    final error = await context.read<FinanceCubit>().deleteMovement(
      id: item.id,
      reason: reason.text,
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(error ?? 'تم حذف الحركة المالية.')));
    if (error == null) await context.read<FinanceCubit>().load();
  }

  Future<void> _editNote(BuildContext context, FinancialMovement item) async {
    final note = TextEditingController(text: item.note ?? '');
    final reason = TextEditingController();
    final accepted = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('تعديل بيان الحركة'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: note,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(labelText: 'البيان'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: reason,
                minLines: 1,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'سبب التعديل *'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(d, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(d, true),
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
    if (accepted != true || !context.mounted) return;
    final error = await context.read<FinanceCubit>().updateNote(
      id: item.id,
      note: note.text,
      reason: reason.text,
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(error ?? 'تم تعديل بيان الحركة.')));
    if (error == null) await context.read<FinanceCubit>().load();
  }

  Future<void> _printMovement(FinancialMovement item) =>
      ReceiptPrinter.printTravelerReceipt(
        receiptNo: item.receiptNo,
        travelerName: item.travelerName ?? _type(item.type),
        phone: '—',
        amount: item.amount,
        method: item.paymentMethod,
        date: item.createdAt,
        status: item.status,
        note: item.note,
        partyLabel: 'الطرف',
      );

  @override
  Widget build(BuildContext context) => AppScaffold(
    title: 'الحركات المالية',
    actions: [
      Padding(
        padding: const EdgeInsetsDirectional.only(end: 12),
        child: FilledButton.icon(
          onPressed: () => _addRevenue(context),
          icon: const Icon(Icons.add),
          label: const Text('إيراد عام'),
        ),
      ),
    ],
    child: BlocBuilder<FinanceCubit, FinanceState>(
      builder: (context, state) {
        if (state is FinanceLoading || state is FinanceInitial)
          return const AppLoadingSkeleton();
        if (state is FinanceFailure)
          return Padding(
            padding: const EdgeInsets.all(20),
            child: ErrorPanel(
              message: state.message,
              onRetry: () => context.read<FinanceCubit>().load(),
            ),
          );
        final loaded = state as FinanceLoaded;
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const SectionTitle(
              'خزنة المكتب',
              subtitle: 'الحذف يزيل الحركة من الخزنة ولا ينشئ حركة عكسية.',
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _metric('إجمالي الداخل', loaded.totalIn, AppTheme.green),
                _metric('إجمالي الخارج', loaded.totalOut, Colors.red.shade700),
                _metric(
                  'صافي الحركة',
                  loaded.net,
                  loaded.net >= 0 ? AppTheme.green : Colors.red.shade700,
                ),
              ],
            ),
            const SizedBox(height: 22),
            const SectionTitle('سجل الحركات'),
            const SizedBox(height: 10),
            if (loaded.items.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(
                    child: Text('لا توجد حركات مالية في الفترة الحالية.'),
                  ),
                ),
              )
            else
              ...loaded.items.map(
                (item) => Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor:
                          (item.isCredit ? AppTheme.green : Colors.red)
                              .withValues(alpha: .09),
                      child: Icon(
                        item.isCredit ? Icons.south_west : Icons.north_east,
                        color: item.isCredit ? AppTheme.green : Colors.red,
                      ),
                    ),
                    title: Text(
                      _type(item.type),
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    subtitle: Text(
                      '${item.receiptNo} • ${item.travelerName ?? item.note ?? '—'}\n${item.createdAt.year}-${item.createdAt.month.toString().padLeft(2, '0')}-${item.createdAt.day.toString().padLeft(2, '0')} • ${_method(item.paymentMethod)} • ${item.status == 'posted'
                          ? 'مسجلة'
                          : item.status == 'reversed'
                          ? 'معكوسة'
                          : 'ملغاة'}',
                    ),
                    isThreeLine: true,
                    trailing: PopupMenuButton<String>(
                      tooltip: 'إجراءات الحركة',
                      onSelected: (v) {
                        switch (v) {
                          case 'edit':
                            _editNote(context, item);
                            break;
                          case 'delete':
                            _deleteMovement(context, item);
                            break;
                          case 'print':
                            _printMovement(item);
                            break;
                        }
                      },
                      itemBuilder: (_) => [
                        if (item.isPosted)
                          const PopupMenuItem(
                            value: 'edit',
                            child: ListTile(
                              dense: true,
                              leading: Icon(Icons.edit_outlined),
                              title: Text('تعديل البيان'),
                            ),
                          ),
                        if (item.status != 'void')
                          const PopupMenuItem(
                            value: 'delete',
                            child: ListTile(
                              dense: true,
                              leading: Icon(Icons.delete_outline),
                              title: Text('حذف الحركة نهائيًا'),
                            ),
                          ),
                        const PopupMenuItem(
                          value: 'print',
                          child: ListTile(
                            dense: true,
                            leading: Icon(Icons.print_outlined),
                            title: Text('طباعة الإيصال'),
                          ),
                        ),
                      ],
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${item.amount.toStringAsFixed(2)} ج.م',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              color: item.isCredit
                                  ? AppTheme.green
                                  : Colors.red.shade700,
                            ),
                          ),
                          const Icon(Icons.more_vert),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    ),
  );

  static Widget _metric(String label, double value, Color color) => SizedBox(
    width: 230,
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(color: Colors.grey.shade700)),
            const SizedBox(height: 8),
            Text(
              '${value.toStringAsFixed(2)} ج.م',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
          ],
        ),
      ),
    ),
  );
  static String _type(String v) => switch (v) {
    'traveler_collection' => 'تحصيل مسافر',
    'general_revenue' => 'إيراد عام',
    'office_expense' => 'مصروف مكتب',
    'payroll_payment' => 'دفع راتب',
    'reversal' => 'حركة عكسية',
    'correction' => 'تصحيح مالي',
    _ => v,
  };
  static String _method(String v) => switch (v) {
    'cash' => 'نقدي',
    'instapay' => 'إنستاباي',
    'bank_transfer' => 'تحويل بنكي',
    'wallet' => 'محفظة إلكترونية',
    'other' => 'أخرى',
    _ => v,
  };
}
