import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class ReceiptPrinter {
  static Future<void> printTravelerReceipt({
    required String receiptNo,
    required String travelerName,
    required String phone,
    required double amount,
    required String method,
    required DateTime date,
    required String status,
    String? note,
    String partyLabel = 'اسم الطرف',
  }) async {
    final regular = pw.Font.ttf(
      await rootBundle.load('assets/fonts/NotoSansArabic-Regular.ttf'),
    );
    final bold = pw.Font.ttf(
      await rootBundle.load('assets/fonts/NotoSansArabic-Bold.ttf'),
    );
    final doc = pw.Document(
      theme: pw.ThemeData.withFont(base: regular, bold: bold),
    );
    final fmt = NumberFormat('#,##0.00', 'en');
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a5,
        theme: pw.ThemeData.withFont(base: regular, bold: bold),
        margin: const pw.EdgeInsets.all(28),
        build: (context) => pw.Directionality(
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
              pw.SizedBox(height: 6),
              pw.Text(
                'إيصال مالي',
                style: pw.TextStyle(font: bold, fontSize: 16),
              ),
              pw.Divider(color: PdfColor.fromHex('#D7B56D'), thickness: 2),
              _line(
                'رقم الإيصال',
                _cleanSerial(receiptNo),
                bold,
                valueDirection: pw.TextDirection.ltr,
                valueFont: regular,
              ),
              _line(
                'التاريخ',
                DateFormat('yyyy-MM-dd HH:mm').format(date),
                bold,
                valueDirection: pw.TextDirection.ltr,
                valueFont: regular,
              ),
              _line(partyLabel, travelerName, bold),
              _line(
                'رقم الهاتف',
                phone,
                bold,
                valueDirection: pw.TextDirection.ltr,
                valueFont: regular,
              ),
              _line('طريقة الدفع', _method(method), bold),
              _line(
                'حالة الحركة',
                status == 'posted' ? 'مسجلة' : 'معكوسة/ملغاة',
                bold,
              ),
              pw.SizedBox(height: 18),
              pw.Container(
                padding: const pw.EdgeInsets.all(14),
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromHex('#F4F1E8'),
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'المبلغ المستلم',
                      style: pw.TextStyle(font: bold, fontSize: 13),
                    ),
                    pw.Text(
                      '${fmt.format(amount)} ج.م',
                      style: pw.TextStyle(
                        font: bold,
                        fontSize: 18,
                        color: PdfColor.fromHex('#174B3B'),
                      ),
                    ),
                  ],
                ),
              ),
              if (note != null && note.trim().isNotEmpty)
                pw.Padding(
                  padding: const pw.EdgeInsets.only(top: 14),
                  child: _line('البيان', note, bold),
                ),
              pw.Spacer(),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('توقيع المستلم:              '),
                  pw.Text('اعتماد الإدارة:             '),
                ],
              ),
              pw.SizedBox(height: 12),
              pw.Center(
                child: pw.Text(
                  'هذا الإيصال ناتج عن حركة مالية محفوظة في النظام',
                  style: pw.TextStyle(font: regular, fontSize: 8, color: PdfColors.grey),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await Printing.layoutPdf(
      onLayout: (format) => doc.save(),
      name: 'SWS-$receiptNo.pdf',
    );
  }

  static Future<void> printPayrollReceipt({
    required String receiptNo,
    required String employeeName,
    required double amount,
    required String method,
    required DateTime date,
    required String month,
    required double baseSalary,
    required double bonus,
    required double overtime,
    required double deductions,
    required String note,
  }) async {
    final regular = pw.Font.ttf(
      await rootBundle.load('assets/fonts/NotoSansArabic-Regular.ttf'),
    );
    final bold = pw.Font.ttf(
      await rootBundle.load('assets/fonts/NotoSansArabic-Bold.ttf'),
    );
    final doc = pw.Document(
      theme: pw.ThemeData.withFont(base: regular, bold: bold),
    );
    final fmt = NumberFormat('#,##0.00', 'en');
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a5,
        margin: const pw.EdgeInsets.all(28),
        theme: pw.ThemeData.withFont(base: regular, bold: bold),
        build: (context) => pw.Directionality(
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
              pw.SizedBox(height: 6),
              pw.Text(
                'إيصال صرف راتب',
                style: pw.TextStyle(font: bold, fontSize: 16),
              ),
              pw.Divider(color: PdfColor.fromHex('#D7B56D'), thickness: 2),
              _line(
                'رقم الإيصال',
                _cleanSerial(receiptNo),
                bold,
                valueDirection: pw.TextDirection.ltr,
                valueFont: regular,
              ),
              _line(
                'التاريخ',
                DateFormat('yyyy-MM-dd HH:mm').format(date),
                bold,
                valueDirection: pw.TextDirection.ltr,
                valueFont: regular,
              ),
              _line('اسم الموظف', employeeName, bold),
              _line('شهر الاستحقاق', month, bold),
              _line('طريقة الدفع', _method(method), bold),
              pw.SizedBox(height: 12),
              _line('الراتب الأساسي', '${fmt.format(baseSalary)} ج.م', bold),
              _line('المكافأة', '${fmt.format(bonus)} ج.م', bold),
              _line('الأوفر تايم', '${fmt.format(overtime)} ج.م', bold),
              _line('الخصومات', '${fmt.format(deductions)} ج.م', bold),
              pw.Container(
                padding: const pw.EdgeInsets.all(14),
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromHex('#F4F1E8'),
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'المبلغ المصروف',
                      style: pw.TextStyle(font: bold, fontSize: 13),
                    ),
                    pw.Text(
                      '${fmt.format(amount)} ج.م',
                      style: pw.TextStyle(
                        font: bold,
                        fontSize: 18,
                        color: PdfColor.fromHex('#174B3B'),
                      ),
                    ),
                  ],
                ),
              ),
              if (note.trim().isNotEmpty)
                pw.Padding(
                  padding: const pw.EdgeInsets.only(top: 12),
                  child: _line('البيان', note, bold),
                ),
              pw.Spacer(),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('توقيع المستلم: ______________'),
                  pw.Text('اعتماد الإدارة: ______________'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    await Printing.layoutPdf(
      onLayout: (format) => doc.save(),
      name: 'SWS-$receiptNo.pdf',
    );
  }

  static Future<void> printOfficeExpenseReceipt({
    required String receiptNo,
    required String category,
    required String description,
    required double amount,
    required String method,
    required DateTime date,
    required String status,
  }) async {
    final regular = pw.Font.ttf(await rootBundle.load('assets/fonts/NotoSansArabic-Regular.ttf'));
    final bold = pw.Font.ttf(await rootBundle.load('assets/fonts/NotoSansArabic-Bold.ttf'));
    final doc = pw.Document(theme: pw.ThemeData.withFont(base: regular, bold: bold));
    final fmt = NumberFormat('#,##0.00', 'en');
    doc.addPage(pw.Page(pageFormat: PdfPageFormat.a5, margin: const pw.EdgeInsets.all(28), theme: pw.ThemeData.withFont(base: regular, bold: bold), build: (_) => pw.Directionality(textDirection: pw.TextDirection.rtl, child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
      pw.Text('شركة شمس الإبداع', style: pw.TextStyle(font: bold, fontSize: 20, color: PdfColor.fromHex('#174B3B'))),
      pw.SizedBox(height: 6), pw.Text('إيصال مصروف مكتب', style: pw.TextStyle(font: bold, fontSize: 16)),
      pw.Divider(color: PdfColor.fromHex('#D7B56D'), thickness: 2),
      _line(
                'رقم الإيصال',
                _cleanSerial(receiptNo),
                bold,
                valueDirection: pw.TextDirection.ltr,
                valueFont: regular,
              ),
      _line(
        'التاريخ',
        DateFormat('yyyy-MM-dd HH:mm').format(date),
        bold,
        valueDirection: pw.TextDirection.ltr,
        valueFont: regular,
      ),
      _line('التصنيف', category, bold), _line('طريقة الدفع', _method(method), bold),
      _line('حالة الحركة', status == 'posted' ? 'مسجلة' : 'ملغاة/معكوسة', bold),
      if (description.trim().isNotEmpty) _line('البيان', description, bold),
      pw.SizedBox(height: 16), pw.Container(padding: const pw.EdgeInsets.all(14), decoration: pw.BoxDecoration(color: PdfColor.fromHex('#F4F1E8'), borderRadius: pw.BorderRadius.circular(8)), child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('قيمة المصروف', style: pw.TextStyle(font: bold, fontSize: 13)), pw.Text('${fmt.format(amount)} ج.م', style: pw.TextStyle(font: bold, fontSize: 18, color: PdfColor.fromHex('#B42318')))])),
      pw.Spacer(), pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('إعداد: ______________'), pw.Text('اعتماد الإدارة: ______________')]),
      pw.SizedBox(height: 12), pw.Center(child: pw.Text('هذا الإيصال مرتبط بحركة مالية محفوظة في النظام', style: pw.TextStyle(font: regular, fontSize: 8, color: PdfColors.grey))),
    ]))));
    await Printing.layoutPdf(onLayout: (_) => doc.save(), name: 'SWS-Expense-$receiptNo.pdf');
  }

  static Future<void> printPayrollStatement({
    required String recordId,
    required String employeeName,
    required String month,
    required double baseSalary,
    required double commission,
    required double bonus,
    required double overtime,
    required double deductions,
    required double paidAmount,
    required double outstanding,
  }) async {
    final regular = pw.Font.ttf(await rootBundle.load('assets/fonts/NotoSansArabic-Regular.ttf'));
    final bold = pw.Font.ttf(await rootBundle.load('assets/fonts/NotoSansArabic-Bold.ttf'));
    final doc = pw.Document(theme: pw.ThemeData.withFont(base: regular, bold: bold));
    final fmt = NumberFormat('#,##0.00', 'en');
    doc.addPage(pw.Page(pageFormat: PdfPageFormat.a5, margin: const pw.EdgeInsets.all(28), theme: pw.ThemeData.withFont(base: regular, bold: bold), build: (_) => pw.Directionality(textDirection: pw.TextDirection.rtl, child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
      pw.Text('شركة شمس الإبداع', style: pw.TextStyle(font: bold, fontSize: 20, color: PdfColor.fromHex('#174B3B'))),
      pw.SizedBox(height: 6), pw.Text('كشف استحقاق راتب', style: pw.TextStyle(font: bold, fontSize: 16)),
      pw.Divider(color: PdfColor.fromHex('#D7B56D'), thickness: 2),
      _line(
        'رقم السجل',
        _cleanSerial(recordId),
        bold,
        valueDirection: pw.TextDirection.ltr,
        valueFont: regular,
      ), _line('اسم الموظف', employeeName, bold), _line('شهر الاستحقاق', month, bold),
      _line('الراتب الأساسي', '${fmt.format(baseSalary)} ج.م', bold), _line('العمولة', '${fmt.format(commission)} ج.م', bold),
      _line('المكافأة', '${fmt.format(bonus)} ج.م', bold), _line('الأوفر تايم', '${fmt.format(overtime)} ج.م', bold), _line('الخصومات', '${fmt.format(deductions)} ج.م', bold),
      pw.Divider(), _line('إجمالي الاستحقاق', '${fmt.format(baseSalary + commission + bonus + overtime - deductions)} ج.م', bold),
      _line('إجمالي المدفوع', '${fmt.format(paidAmount)} ج.م', bold),
      pw.Container(padding: const pw.EdgeInsets.all(12), decoration: pw.BoxDecoration(color: PdfColor.fromHex('#F4F1E8'), borderRadius: pw.BorderRadius.circular(8)), child: _line('المتبقي', '${fmt.format(outstanding)} ج.م', bold)),
      pw.Spacer(), pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('توقيع الموظف: ______________'), pw.Text('اعتماد الإدارة: ______________')]),
    ]))));
    await Printing.layoutPdf(onLayout: (_) => doc.save(), name: 'SWS-Payroll-$recordId.pdf');
  }

  static pw.Widget _line(
    String label,
    String value,
    pw.Font font, {
    pw.TextDirection? valueDirection,
    pw.Font? valueFont,
  }) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 5),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(
          width: 100,
          child: pw.Text('$label:', style: pw.TextStyle(font: font)),
        ),
        pw.Expanded(
          child: valueDirection == null
              ? pw.Text(value)
              : pw.Directionality(
                  textDirection: valueDirection,
                  child: pw.Text(
                    value,
                    style: pw.TextStyle(font: valueFont ?? font),
                  ),
                ),
        ),
      ],
    ),
  );

  /// Strip invisible bidi/control marks that can be accidentally stored in IDs.
  static String _cleanSerial(String value) => value
      .replaceAll(RegExp(r'[\u0000-\u001F\u007F\u200B-\u200F\u202A-\u202E\u2060\u2066-\u2069\uFEFF]'), '')
      .trim();
  static String _method(String v) => switch (v) {
    'cash' => 'نقدي',
    'instapay' => 'إنستاباي',
    'bank_transfer' => 'تحويل بنكي',
    'wallet' => 'محفظة إلكترونية',
    'other' => 'أخرى',
    _ => v,
  };
}
