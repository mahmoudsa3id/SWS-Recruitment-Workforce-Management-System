import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../../core/di/injection.dart';
import '../../../core/printing/receipt_printer.dart';
import '../../../core/month_scope/accounting_month_scope.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../domain/entities/payroll_record.dart';
import 'cubit/payroll_cubit.dart';
import '../../../core/widgets/app_loading_skeleton.dart';

class PayrollPage extends StatelessWidget {
  const PayrollPage({super.key});
  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => sl<PayrollCubit>()..load(),
    child: const _PayrollView(),
  );
}

class _PayrollView extends StatelessWidget {
  const _PayrollView();

  Future<Map<String, String>?> _salaryDialog(
    BuildContext context, {
    PayrollRecord? record,
  }) async {
    final name = TextEditingController(text: record?.employeeName ?? '');
    final base = TextEditingController(
      text: record?.baseSalary.toStringAsFixed(2) ?? '',
    );
    final commission = TextEditingController(
      text: record?.commission.toStringAsFixed(2) ?? '0',
    );
    final bonus = TextEditingController(
      text: record?.bonus.toStringAsFixed(2) ?? '0',
    );
    final overtimeHours = TextEditingController(
      text: record?.overtimeHours.toStringAsFixed(2) ?? '0',
    );
    final overtimeRate = TextEditingController(
      text: record?.overtimeRate.toStringAsFixed(2) ?? '0',
    );
    final deductions = TextEditingController(
      text: record?.deductions.toStringAsFixed(2) ?? '0',
    );
    final form = GlobalKey<FormState>();
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(
          record == null ? 'استحقاق راتب جديد' : 'تعديل استحقاق الراتب',
        ),
        content: SizedBox(
          width: 440,
          child: Form(
            key: form,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: name,
                    decoration: const InputDecoration(
                      labelText: 'اسم الموظف *',
                    ),
                    validator: (v) => v == null || v.trim().isEmpty
                        ? 'اسم الموظف مطلوب'
                        : null,
                  ),
                  const SizedBox(height: 8),
                  _moneyField(base, 'الراتب الأساسي *', requiredPositive: true),
                  _moneyField(commission, 'العمولة'),
                  _moneyField(bonus, 'المكافأة'),
                  _moneyField(overtimeHours, 'ساعات الأوفر تايم'),
                  _moneyField(overtimeRate, 'سعر ساعة الأوفر تايم'),
                  _moneyField(deductions, 'الخصومات'),
                  if (record != null)
                    const Padding(
                      padding: EdgeInsets.only(top: 10),
                      child: Text(
                        'لا يمكن تعديل استحقاق تم صرف جزء منه. يجب تسوية الدفعات أولًا.',
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
              if (form.currentState?.validate() == true)
                Navigator.pop(d, {
                  'name': name.text.trim(),
                  'base': base.text,
                  'commission': commission.text,
                  'bonus': bonus.text,
                  'hours': overtimeHours.text,
                  'rate': overtimeRate.text,
                  'deductions': deductions.text,
                });
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
    return result;
  }

  TextFormField _moneyField(
    TextEditingController controller,
    String label, {
    bool requiredPositive = false,
  }) => TextFormField(
    controller: controller,
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    decoration: InputDecoration(labelText: label),
    validator: (v) {
      if ((v == null || v.trim().isEmpty) && !requiredPositive) return null;
      final n = double.tryParse(v ?? '');
      return n == null || !n.isFinite || n < 0 || (requiredPositive && n <= 0)
          ? 'أدخل قيمة صحيحة'
          : null;
    },
  );

  Future<void> _create(BuildContext context) async {
    final values = await _salaryDialog(context);
    if (values == null || !context.mounted) return;
    final error = await context.read<PayrollCubit>().create(
      employeeName: values['name']!,
      monthStart: AccountingMonthScope.start,
      baseSalary: _n(values['base']),
      commission: _n(values['commission']),
      bonus: _n(values['bonus']),
      overtimeHours: _n(values['hours']),
      overtimeRate: _n(values['rate']),
      deductions: _n(values['deductions']),
    );
    if (!context.mounted) return;
    _message(context, error ?? 'تم إنشاء الاستحقاق.');
    if (error == null) await context.read<PayrollCubit>().load();
  }

  Future<void> _edit(BuildContext context, PayrollRecord r) async {
    if (r.paidAmount > 0) {
      _message(context, 'لا يمكن تعديل المرتب بعد تسجيل دفعة عليه.');
      return;
    }
    final values = await _salaryDialog(context, record: r);
    if (values == null || !context.mounted) return;
    final error = await context.read<PayrollCubit>().updateRecord(
      payrollId: r.id,
      employeeName: values['name']!,
      baseSalary: _n(values['base']),
      commission: _n(values['commission']),
      bonus: _n(values['bonus']),
      overtimeHours: _n(values['hours']),
      overtimeRate: _n(values['rate']),
      deductions: _n(values['deductions']),
    );
    if (!context.mounted) return;
    _message(context, error ?? 'تم تعديل استحقاق الراتب.');
    if (error == null) await context.read<PayrollCubit>().load();
  }

  Future<void> _delete(BuildContext context, PayrollRecord r) async {
    final reason = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('حذف استحقاق الراتب'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'سيتم حذف استحقاق ${r.employeeName} نهائيًا من قائمة المرتبات. سيتم حذف حركات صرف الراتب المرتبطة به من الخزنة دون إنشاء حركات عكسية. سيُحتفظ بصورة في سجل المراجعة، وسيُمنع الحذف إذا كان الشهر مقفولًا.',
            ),
            TextField(
              controller: reason,
              decoration: const InputDecoration(labelText: 'سبب الحذف *'),
              minLines: 2,
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(d, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(d, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final error = await context.read<PayrollCubit>().deleteRecord(
      payrollId: r.id,
      reason: reason.text,
    );
    if (!context.mounted) return;
    _message(context, error ?? 'تم حذف الاستحقاق.');
    if (error == null) await context.read<PayrollCubit>().load();
  }

  Future<void> _pay(BuildContext context, PayrollRecord r) async {
    final amount = TextEditingController(
      text: r.outstanding.toStringAsFixed(2),
    );
    var method = 'cash';
    final form = GlobalKey<FormState>();
    final accepted = await showDialog<bool>(
      context: context,
      builder: (d) => StatefulBuilder(
        builder: (d, setD) => AlertDialog(
          title: Text('دفع راتب ${r.employeeName}'),
          content: Form(
            key: form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('المتبقي: ${r.outstanding.toStringAsFixed(2)} ج.م'),
                const SizedBox(height: 12),
                TextFormField(
                  controller: amount,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'المبلغ المدفوع *',
                  ),
                  validator: (v) {
                    final n = double.tryParse(v ?? '');
                    return n == null ||
                            !n.isFinite ||
                            n <= 0 ||
                            n > r.outstanding
                        ? 'المبلغ غير صحيح أو أكبر من المتبقي'
                        : null;
                  },
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
                  onChanged: (v) => setD(() => method = v ?? 'cash'),
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
              onPressed: () {
                if (form.currentState?.validate() == true)
                  Navigator.pop(d, true);
              },
              child: const Text('تأكيد الدفع'),
            ),
          ],
        ),
      ),
    );
    if (accepted != true || !context.mounted) return;
    final paid = _n(amount.text);
    final error = await context.read<PayrollCubit>().pay(
      payrollId: r.id,
      amount: paid,
      method: method,
      note: 'دفع راتب ${r.employeeName}',
    );
    if (!context.mounted) return;
    _message(context, error ?? 'تم تسجيل دفعة الراتب.');
    if (error == null) {
      final cubit = context.read<PayrollCubit>();
      await cubit.load();
      final receiptNo = cubit.lastReceiptNo;
      if (receiptNo != null && context.mounted) {
        await ReceiptPrinter.printPayrollReceipt(
          receiptNo: receiptNo,
          employeeName: r.employeeName,
          amount: paid,
          method: method,
          date: DateTime.now(),
          month: DateFormat('yyyy-MM').format(r.monthStart),
          baseSalary: r.baseSalary,
          bonus: r.bonus,
          overtime: r.overtimeAmount,
          deductions: r.deductions,
          note: 'صرف راتب ${r.employeeName}',
        );
      }
    }
  }

  Future<void> _print(PayrollRecord r) => ReceiptPrinter.printPayrollStatement(
    recordId: r.id,
    employeeName: r.employeeName,
    month: DateFormat('yyyy-MM').format(r.monthStart),
    baseSalary: r.baseSalary,
    commission: r.commission,
    bonus: r.bonus,
    overtime: r.overtimeAmount,
    deductions: r.deductions,
    paidAmount: r.paidAmount,
    outstanding: r.outstanding,
  );
  static double _n(String? v) => double.tryParse(v ?? '') ?? 0;
  void _message(BuildContext c, String s) =>
      ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text(s)));

  @override
  Widget build(BuildContext context) => AppScaffold(
    title: 'المرتبات والاستحقاقات',
    actions: [
      Padding(
        padding: const EdgeInsetsDirectional.only(end: 12),
        child: FilledButton.icon(
          onPressed: () => _create(context),
          icon: const Icon(Icons.person_add_alt),
          label: const Text('استحقاق جديد'),
        ),
      ),
    ],
    child: BlocBuilder<PayrollCubit, PayrollState>(
      builder: (context, state) {
        if (state is PayrollInitial || state is PayrollLoading)
          return const AppLoadingSkeleton();
        if (state is PayrollFailure)
          return Padding(
            padding: const EdgeInsets.all(20),
            child: ErrorPanel(
              message: state.message,
              onRetry: () => context.read<PayrollCubit>().load(),
            ),
          );
        final loaded = state as PayrollLoaded;
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const SectionTitle(
              'كشف المرتبات',
              subtitle:
                  'الراتب المستحق لا يُحسب مصروفًا نقديًا إلا عند الدفع الفعلي.',
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    const Icon(Icons.account_balance_wallet_outlined, size: 30),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'إجمالي المستحقات غير المدفوعة',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    Text(
                      '${loaded.totalDue.toStringAsFixed(2)} ج.م',
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 20,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (loaded.records.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('لا توجد استحقاقات رواتب.'),
                ),
              )
            else
              ...loaded.records.map((r) => _recordTile(context, r)),
          ],
        );
      },
    ),
  );

  Widget _recordTile(BuildContext context, PayrollRecord r) => Card(
    child: ListTile(
      leading: const CircleAvatar(child: Icon(Icons.badge_outlined)),
      title: Text(
        r.employeeName,
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
      subtitle: Text(
        '${DateFormat('yyyy-MM').format(r.monthStart)} • الأساسي ${r.baseSalary.toStringAsFixed(2)} • عمولة ${r.commission.toStringAsFixed(2)} • مكافأة ${r.bonus.toStringAsFixed(2)} • أوفر تايم ${r.overtimeAmount.toStringAsFixed(2)} • خصومات ${r.deductions.toStringAsFixed(2)}\nمدفوع ${r.paidAmount.toStringAsFixed(2)} ج.م',
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
      ),
      isThreeLine: true,
      trailing: PopupMenuButton<String>(
        tooltip: 'إجراءات المرتب',
        onSelected: (v) {
          switch (v) {
            case 'pay':
              _pay(context, r);
              break;
            case 'edit':
              _edit(context, r);
              break;
            case 'delete':
              _delete(context, r);
              break;
            case 'print':
              _print(r);
              break;
          }
        },
        itemBuilder: (_) => [
          if (r.outstanding > 0)
            const PopupMenuItem(
              value: 'pay',
              child: ListTile(
                dense: true,
                leading: Icon(Icons.payments_outlined),
                title: Text('تسجيل دفع'),
              ),
            ),
          const PopupMenuItem(
            value: 'edit',
            child: ListTile(
              dense: true,
              leading: Icon(Icons.edit_outlined),
              title: Text('تعديل الاستحقاق'),
            ),
          ),
          const PopupMenuItem(
            value: 'delete',
            child: ListTile(
              dense: true,
              leading: Icon(Icons.delete_outline),
              title: Text('حذف الاستحقاق'),
            ),
          ),
          const PopupMenuItem(
            value: 'print',
            child: ListTile(
              dense: true,
              leading: Icon(Icons.print_outlined),
              title: Text('طباعة كشف الراتب'),
            ),
          ),
        ],
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'متبقي ${r.outstanding.toStringAsFixed(2)}',
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
            const Icon(Icons.more_vert),
          ],
        ),
      ),
    ),
  );
}
