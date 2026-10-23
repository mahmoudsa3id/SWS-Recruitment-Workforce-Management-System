import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/di/injection.dart';
import '../../../core/printing/receipt_printer.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../domain/entities/office_expense.dart';
import 'cubit/expenses_cubit.dart';
import '../../../core/widgets/app_loading_skeleton.dart';

class ExpensesPage extends StatelessWidget {
  const ExpensesPage({super.key});
  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => sl<ExpensesCubit>()..load(),
    child: const _ExpensesView(),
  );
}

class _ExpensesView extends StatelessWidget {
  const _ExpensesView();
  static const _methods = <String, String>{
    'cash': 'نقدي',
    'instapay': 'إنستاباي',
    'bank_transfer': 'تحويل بنكي',
    'wallet': 'محفظة إلكترونية',
    'other': 'أخرى',
  };

  Future<Map<String, String>?> _expenseDialog(
    BuildContext context, {
    OfficeExpense? expense,
  }) async {
    final category = TextEditingController(text: expense?.category ?? '');
    final description = TextEditingController(text: expense?.description ?? '');
    final amount = TextEditingController(
      text: expense?.amount.toStringAsFixed(2) ?? '',
    );
    var method = expense?.method ?? 'cash';
    final form = GlobalKey<FormState>();
    return showDialog<Map<String, String>>(
      context: context,
      builder: (d) => StatefulBuilder(
        builder: (d, setD) => AlertDialog(
          title: Text(expense == null ? 'مصروف جديد' : 'تعديل المصروف'),
          content: SizedBox(
            width: 420,
            child: Form(
              key: form,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: category,
                      decoration: const InputDecoration(labelText: 'التصنيف *'),
                      validator: (v) => v == null || v.trim().isEmpty
                          ? 'التصنيف مطلوب'
                          : null,
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: description,
                      decoration: const InputDecoration(labelText: 'البيان'),
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: amount,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(labelText: 'المبلغ *'),
                      validator: (v) {
                        final n = double.tryParse(v ?? '');
                        return n == null || !n.isFinite || n <= 0
                            ? 'أدخل مبلغًا صحيحًا'
                            : null;
                      },
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: method,
                      decoration: const InputDecoration(
                        labelText: 'طريقة الدفع',
                      ),
                      items: _methods.entries
                          .map(
                            (e) => DropdownMenuItem(
                              value: e.key,
                              child: Text(e.value),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setD(() => method = v ?? 'cash'),
                    ),
                    if (expense != null)
                      const Padding(
                        padding: EdgeInsets.only(top: 10),
                        child: Text(
                          'تعديل المبلغ أو طريقة الدفع يحدّث حركة الخزنة نفسها، مع حفظ التفاصيل السابقة في سجل المراجعة.',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(d),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () {
                if (form.currentState?.validate() == true) {
                  Navigator.pop(d, {
                    'category': category.text.trim(),
                    'description': description.text.trim(),
                    'amount': amount.text,
                    'method': method,
                  });
                }
              },
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
  }

  Future<String?> _reason(
    BuildContext context, {
    required String title,
    required String hint,
  }) async {
    final reason = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: reason,
          autofocus: true,
          minLines: 2,
          maxLines: 3,
          decoration: InputDecoration(labelText: hint),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(d),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(d, reason.text.trim()),
            child: const Text('تأكيد'),
          ),
        ],
      ),
    );
  }

  Future<void> _add(BuildContext context) async {
    final values = await _expenseDialog(context);
    if (values == null || !context.mounted) return;
    final error = await context.read<ExpensesCubit>().create(
      amount: double.parse(values['amount']!),
      method: values['method']!,
      category: values['category']!,
      description: values['description']!,
    );
    if (!context.mounted) return;
    _message(context, error ?? 'تم تسجيل المصروف.');
    if (error == null) await context.read<ExpensesCubit>().load();
  }

  Future<void> _edit(BuildContext context, OfficeExpense e) async {
    if (e.status != 'posted') {
      _message(context, 'لا يمكن تعديل مصروف ملغى أو معكوس.');
      return;
    }
    final values = await _expenseDialog(context, expense: e);
    if (values == null || !context.mounted) return;
    final reason = await _reason(
      context,
      title: 'سبب تعديل المصروف',
      hint: 'سبب التعديل *',
    );
    if (reason == null || reason.isEmpty || !context.mounted) return;
    final error = await context.read<ExpensesCubit>().updateExpense(
      expenseId: e.id,
      amount: double.parse(values['amount']!),
      method: values['method']!,
      category: values['category']!,
      description: values['description']!,
      reason: reason,
    );
    if (!context.mounted) return;
    _message(context, error ?? 'تم تعديل المصروف وتحديث أثر الخزنة.');
    if (error == null) await context.read<ExpensesCubit>().load();
  }

  Future<void> _delete(BuildContext context, OfficeExpense e) async {
    if (e.status != 'posted') {
      _message(context, 'المصروف غير مسجل كحركة فعالة.');
      return;
    }
    final reason = await _reason(
      context,
      title: 'حذف المصروف',
      hint: 'سبب الحذف *',
    );
    if (reason == null || reason.isEmpty || !context.mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('تأكيد حذف المصروف'),
        content: const Text(
          'سيُحذف المصروف وحركة الخزنة المرتبطة به نهائيًا، دون إنشاء حركة عكسية. سيؤثر ذلك على رصيد الخزنة؛ سيُحتفظ بصورة في سجل المراجعة.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(d, false),
            child: const Text('رجوع'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(d, true),
            child: const Text('تأكيد الحذف'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final error = await context.read<ExpensesCubit>().deleteExpense(
      expenseId: e.id,
      reason: reason,
    );
    if (!context.mounted) return;
    _message(context, error ?? 'تم حذف المصروف وحركة الخزنة المرتبطة به.');
    if (error == null) await context.read<ExpensesCubit>().load();
  }

  Future<void> _print(OfficeExpense e) =>
      ReceiptPrinter.printOfficeExpenseReceipt(
        receiptNo: e.receiptNo,
        category: e.category,
        description: e.description,
        amount: e.amount,
        method: e.method,
        date: e.createdAt,
        status: e.status,
      );
  void _message(BuildContext c, String s) =>
      ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text(s)));

  @override
  Widget build(BuildContext context) => AppScaffold(
    title: 'مصروفات المكتب',
    actions: [
      Padding(
        padding: const EdgeInsetsDirectional.only(end: 12),
        child: FilledButton.icon(
          onPressed: () => _add(context),
          icon: const Icon(Icons.add),
          label: const Text('مصروف جديد'),
        ),
      ),
    ],
    child: BlocBuilder<ExpensesCubit, ExpensesState>(
      builder: (context, state) {
        if (state is ExpensesInitial || state is ExpensesLoading) {
          return const AppLoadingSkeleton();
        }
        if (state is ExpensesFailure) {
          return Padding(
            padding: const EdgeInsets.all(20),
            child: ErrorPanel(
              message: state.message,
              onRetry: () => context.read<ExpensesCubit>().load(),
            ),
          );
        }
        final items = (state as ExpensesLoaded).items;
        final total = items
            .where((e) => e.status == 'posted')
            .fold<double>(0, (s, e) => s + e.amount);
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const SectionTitle(
              'مصروفات المكتب',
              subtitle:
                  'كل مصروف مرتبط بحركة خزنة واحدة. تعديل أو حذف الحركة ينعكس مباشرة على رصيد الخزنة.',
            ),
            const SizedBox(height: 14),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    const Icon(Icons.payments_outlined, size: 30),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'إجمالي المصروفات المسجلة',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    Text(
                      '${total.toStringAsFixed(2)} ج.م',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: Colors.red,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            if (items.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('لا توجد مصروفات مسجلة.'),
                ),
              )
            else
              ...items.map((e) => _tile(context, e)),
          ],
        );
      },
    ),
  );

  Widget _tile(BuildContext context, OfficeExpense e) => Card(
    child: ListTile(
      leading: const CircleAvatar(child: Icon(Icons.receipt_long_outlined)),
      title: Text(
        e.category,
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
      subtitle: Text(
        '${e.description}\n${e.createdAt.year}-${e.createdAt.month.toString().padLeft(2, '0')}-${e.createdAt.day.toString().padLeft(2, '0')} • ${e.receiptNo} • ${_methods[e.method] ?? e.method}',
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
      ),
      isThreeLine: true,
      trailing: PopupMenuButton<String>(
        tooltip: 'إجراءات المصروف',
        onSelected: (v) {
          switch (v) {
            case 'edit':
              _edit(context, e);
              break;
            case 'delete':
              _delete(context, e);
              break;
            case 'print':
              _print(e);
              break;
          }
        },
        itemBuilder: (_) => [
          const PopupMenuItem(
            value: 'edit',
            child: ListTile(
              dense: true,
              leading: Icon(Icons.edit_outlined),
              title: Text('تعديل المصروف'),
            ),
          ),
          const PopupMenuItem(
            value: 'delete',
            child: ListTile(
              dense: true,
              leading: Icon(Icons.delete_outline),
              title: Text('حذف المصروف'),
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
          children: [
            Text(
              '${e.amount.toStringAsFixed(2)} ج.م',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                color: e.status == 'posted' ? Colors.red : Colors.grey,
              ),
            ),
            const Icon(Icons.more_vert),
          ],
        ),
      ),
    ),
  );
}
