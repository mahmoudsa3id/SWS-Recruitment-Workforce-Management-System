import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:flutter/services.dart';
import 'package:printing/printing.dart';
import '../../../core/di/injection.dart';
import '../../../core/month_scope/accounting_month_scope.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../domain/entities/monthly_financial_report.dart';
import 'cubit/reports_cubit.dart';
import '../../../core/widgets/app_loading_skeleton.dart';

class ReportsPage extends StatelessWidget {
  const ReportsPage({super.key});
  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => sl<ReportsCubit>()..load(AccountingMonthScope.start),
    child: const _ReportsView(),
  );
}

class _ReportsView extends StatefulWidget {
  const _ReportsView();
  @override
  State<_ReportsView> createState() => _ReportsViewState();
}

class _ReportsViewState extends State<_ReportsView> {
  DateTime month = AccountingMonthScope.start;

  @override
  void initState() {
    super.initState();
    AccountingMonthScope.selected.addListener(_onSharedMonthChanged);
  }

  void _onSharedMonthChanged() {
    if (!mounted) return;
    final selected = AccountingMonthScope.start;
    if (month.year == selected.year && month.month == selected.month) return;
    setState(() => month = selected);
  }

  @override
  void dispose() {
    AccountingMonthScope.selected.removeListener(_onSharedMonthChanged);
    super.dispose();
  }

  void _move(int by) {
    final next = DateTime(month.year, month.month + by, 1);
    AccountingMonthScope.select(next);
  }

  Future<void> _print(MonthlyFinancialReport report) async {
    final regular = pw.Font.ttf(
      await rootBundle.load('assets/fonts/NotoSansArabic-Regular.ttf'),
    );
    final bold = pw.Font.ttf(
      await rootBundle.load('assets/fonts/NotoSansArabic-Bold.ttf'),
    );
    final theme = pw.ThemeData.withFont(base: regular, bold: bold);
    final document = pw.Document(theme: theme);
    final rows = <List<String>>[
      ['رصيد أول المدة', '${report.openingBalance.toStringAsFixed(2)} ج.م'],
      [
        'تحصيل المسافرين',
        '${report.travelerCollections.toStringAsFixed(2)} ج.م',
      ],
      ['الإيرادات العامة', '${report.generalRevenue.toStringAsFixed(2)} ج.م'],
      ['إجمالي الداخل', '${report.totalIncome.toStringAsFixed(2)} ج.م'],
      ['مصروفات المكتب', '${report.officeExpenses.toStringAsFixed(2)} ج.م'],
      ['مدفوعات المرتبات', '${report.payrollPayments.toStringAsFixed(2)} ج.م'],
      ['إجمالي الخارج', '${report.totalExpenses.toStringAsFixed(2)} ج.م'],
      ['صافي الحركة', '${report.netMovement.toStringAsFixed(2)} ج.م'],
      ['رصيد نهاية المدة', '${report.closingBalance.toStringAsFixed(2)} ج.م'],
    ];
    document.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        theme: theme,
        margin: const pw.EdgeInsets.all(32),
        build: (_) => pw.Directionality(
          textDirection: pw.TextDirection.rtl,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              pw.Text(
                'شركة شمس الإبداع',
                style: pw.TextStyle(
                  font: bold,
                  fontSize: 20,
                  color: PdfColor.fromHex('#174B3B'),
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Text(
                'التقرير المالي الشهري  ${DateFormat('yyyy-MM').format(report.monthStart)}',
                style: pw.TextStyle(font: bold, fontSize: 15),
              ),
              pw.SizedBox(height: 18),
              pw.TableHelper.fromTextArray(
                headers: ['البند', 'القيمة'],
                data: rows,
                border: pw.TableBorder.all(color: PdfColor.fromHex('#D8DED8')),
                headerDecoration: pw.BoxDecoration(
                  color: PdfColor.fromHex('#E7EFE9'),
                ),
                headerStyle: pw.TextStyle(font: bold),
                cellStyle: pw.TextStyle(font: regular, fontSize: 10),
                cellAlignment: pw.Alignment.centerRight,
              ),
              pw.Spacer(),
              pw.Text(
                'تم إنشاء التقرير من الحركات المسجلة في نظام SWS.',
                style: pw.TextStyle(
                  font: regular,
                  fontSize: 8,
                  color: PdfColors.grey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await Printing.layoutPdf(
      name:
          'SWS-Monthly-${DateFormat('yyyy-MM').format(report.monthStart)}.pdf',
      onLayout: (_) => document.save(),
    );
  }

  Future<void> _exportExcel(MonthlyFinancialReport report) async {
    try {
      final workbook = Excel.createExcel();
      final sheet = workbook['التقرير المالي'];
      sheet.appendRow([TextCellValue('شركة شمس الإبداع')]);
      sheet.appendRow([
        TextCellValue('التقرير المالي الشهري'),
        TextCellValue(DateFormat('yyyy-MM').format(report.monthStart)),
      ]);
      sheet.appendRow([
        TextCellValue('البند'),
        TextCellValue('القيمة بالجنيه المصري'),
      ]);
      final rows = <MapEntry<String, double>>[
        MapEntry('رصيد أول المدة', report.openingBalance),
        MapEntry('تحصيل المسافرين', report.travelerCollections),
        MapEntry('الإيرادات العامة', report.generalRevenue),
        MapEntry('إجمالي الداخل', report.totalIncome),
        MapEntry('مصروفات المكتب', report.officeExpenses),
        MapEntry('مدفوعات المرتبات', report.payrollPayments),
        MapEntry('إجمالي الخارج', report.totalExpenses),
        MapEntry('حركات دائنة أخرى', report.otherCredits),
        MapEntry('حركات مدينة أخرى', report.otherDebits),
        MapEntry('صافي الحركة', report.netMovement),
        MapEntry('رصيد نهاية المدة', report.closingBalance),
      ];
      for (final row in rows) {
        sheet.appendRow([TextCellValue(row.key), DoubleCellValue(row.value)]);
      }
      final bytes = workbook.save();
      if (bytes == null || bytes.isEmpty) {
        throw StateError('The Excel workbook could not be serialized.');
      }
      final monthLabel = DateFormat('yyyy-MM').format(report.monthStart);
      final saved = await FilePicker.saveFile(
        dialogTitle: 'حفظ التقرير المالي Excel',
        fileName: 'SWS-Report-$monthLabel.xlsx',
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
        bytes: Uint8List.fromList(bytes),
      );
      if (!mounted || saved == null) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حفظ ملف Excel للتقرير المالي.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'تعذر تصدير Excel. تحقق من إصدار Flutter ثم حاول مرة أخرى.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => AppScaffold(
    title: 'التقارير المالية',
    actions: [
      IconButton(
        tooltip: 'الشهر السابق',
        onPressed: () => _move(-1),
        icon: const Icon(Icons.chevron_right),
      ),
      IconButton(
        tooltip: 'الشهر التالي',
        onPressed: () => _move(1),
        icon: const Icon(Icons.chevron_left),
      ),
    ],
    child: BlocBuilder<ReportsCubit, ReportsState>(
      builder: (context, state) {
        if (state is ReportsInitial || state is ReportsLoading)
          return const AppLoadingSkeleton();
        if (state is ReportsFailure)
          return Padding(
            padding: const EdgeInsets.all(20),
            child: ErrorPanel(
              message: state.message,
              onRetry: () => context.read<ReportsCubit>().load(month),
            ),
          );
        final r = (state as ReportsLoaded).report;
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            SectionTitle(
              'التقرير المالي — ${DateFormat('MMMM yyyy', 'ar').format(r.monthStart)}',
              subtitle: 'الأرقام محسوبة من حركات الشهر المسجلة فقط.',
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _metric('رصيد أول المدة', r.openingBalance, AppTheme.ink),
                _metric('إجمالي الداخل', r.totalIncome, AppTheme.green),
                _metric('إجمالي الخارج', r.totalExpenses, Colors.red.shade700),
                _metric(
                  'صافي الحركة',
                  r.netMovement,
                  r.netMovement >= 0 ? AppTheme.green : Colors.red.shade700,
                ),
                _metric('رصيد نهاية المدة', r.closingBalance, AppTheme.green),
              ],
            ),
            const SizedBox(height: 18),
            const SectionTitle('تفصيل الحركة'),
            const SizedBox(height: 8),
            _row('تحصيل المسافرين', r.travelerCollections),
            _row('الإيرادات العامة', r.generalRevenue),
            _row('مصروفات المكتب', r.officeExpenses),
            _row('مدفوعات المرتبات', r.payrollPayments),
            if (r.otherCredits > 0)
              _row('إيرادات/حركات دائنة أخرى', r.otherCredits),
            if (r.otherDebits > 0) _row('حركات مدينة أخرى', r.otherDebits),
            const SizedBox(height: 18),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                FilledButton.icon(
                  onPressed: () => _print(r),
                  icon: const Icon(Icons.picture_as_pdf_outlined),
                  label: const Text('تصدير PDF'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _exportExcel(r),
                  icon: const Icon(Icons.table_view_outlined),
                  label: const Text('تصدير Excel'),
                ),
              ],
            ),
          ],
        );
      },
    ),
  );
  Widget _metric(String title, double value, Color color) => SizedBox(
    width: 220,
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(color: Colors.grey.shade700)),
            const SizedBox(height: 8),
            Text(
              '${value.toStringAsFixed(2)} ج.م',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
          ],
        ),
      ),
    ),
  );
  Widget _row(String title, double amount) => Card(
    child: ListTile(
      title: Text(title),
      trailing: Text(
        '${amount.toStringAsFixed(2)} ج.م',
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
    ),
  );
}
