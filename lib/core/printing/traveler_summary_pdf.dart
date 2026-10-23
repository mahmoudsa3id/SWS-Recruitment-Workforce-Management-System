import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../features/travelers/domain/entities/traveler_profile.dart';

/// Builds the Arabic overview PDF that is packaged with the original documents.
class TravelerSummaryPdf {
  TravelerSummaryPdf._();

  static Future<List<int>> build(TravelerProfile profile) async {
    final regular = pw.Font.ttf(
      await rootBundle.load('assets/fonts/NotoSansArabic-Regular.ttf'),
    );
    final bold = pw.Font.ttf(
      await rootBundle.load('assets/fonts/NotoSansArabic-Bold.ttf'),
    );
    final theme = pw.ThemeData.withFont(base: regular, bold: bold);
    final traveler = profile.traveler;
    final money = NumberFormat('#,##0.00', 'en');
    final date = DateFormat('yyyy-MM-dd HH:mm');
    final document = pw.Document(theme: theme);

    pw.Widget valueRow(String label, String value) => pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 5),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 130,
            child: pw.Text(label, style: pw.TextStyle(font: bold)),
          ),
          pw.Expanded(child: pw.Text(value)),
        ],
      ),
    );

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(30),
        theme: theme,
        build: (context) => [
          pw.Directionality(
            textDirection: pw.TextDirection.rtl,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                pw.Text(
                  'شركة شمس الإبداع',
                  style: pw.TextStyle(
                    font: bold,
                    fontSize: 21,
                    color: PdfColor.fromHex('#174B3B'),
                  ),
                ),
                pw.SizedBox(height: 5),
                pw.Text(
                  'ملف المسافر - ملخص البيانات والحساب',
                  style: pw.TextStyle(font: bold, fontSize: 16),
                ),
                pw.Divider(color: PdfColor.fromHex('#C6A66B'), thickness: 2),
                valueRow('رقم الملف', traveler.fileNo ?? '-'),
                valueRow('الاسم بالكامل', traveler.fullName),
                valueRow('رقم الهاتف', traveler.phone),
                valueRow('الوجهة', traveler.destinationCountry ?? '-'),
                valueRow('مسؤول المبيعات', traveler.salesPerson ?? '-'),
                valueRow(
                  'تاريخ التسجيل',
                  DateFormat('yyyy-MM-dd').format(traveler.createdAt),
                ),
                pw.SizedBox(height: 12),
                pw.Container(
                  padding: const pw.EdgeInsets.all(14),
                  decoration: pw.BoxDecoration(
                    color: PdfColor.fromHex('#F4F1E8'),
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                    children: [
                      valueRow(
                        'إجمالي الاتفاق',
                        '${money.format(traveler.agreementTotal)} ج.م',
                      ),
                      valueRow(
                        'صافي التحصيل',
                        '${money.format(profile.netPaid)} ج.م',
                      ),
                      valueRow(
                        'المتبقي',
                        '${money.format(profile.remaining)} ج.م',
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 18),
                pw.Text(
                  'مراحل المسافر',
                  style: pw.TextStyle(font: bold, fontSize: 14),
                ),
                pw.SizedBox(height: 5),
                valueRow('قدم', traveler.submitted ? 'تم' : 'لم يتم'),
                valueRow('كشف', traveler.inspected ? 'تم' : 'لم يتم'),
                valueRow('تأشيرة', traveler.visaIssued ? 'تم' : 'لم يتم'),
                valueRow('طيران', traveler.flightBooked ? 'تم' : 'لم يتم'),
                pw.SizedBox(height: 18),
                pw.Text(
                  'سجل الدفعات والحركات',
                  style: pw.TextStyle(font: bold, fontSize: 14),
                ),
                pw.SizedBox(height: 7),
                if (profile.payments.isEmpty)
                  pw.Text('لا توجد حركات مسجلة.')
                else
                  pw.Table(
                    border: pw.TableBorder.all(
                      color: PdfColor.fromHex('#D8DED6'),
                      width: .5,
                    ),
                    columnWidths: const {
                      0: pw.FlexColumnWidth(2.2),
                      1: pw.FlexColumnWidth(1.5),
                      2: pw.FlexColumnWidth(1.6),
                      3: pw.FlexColumnWidth(2),
                    },
                    children: [
                      pw.TableRow(
                        decoration: pw.BoxDecoration(
                          color: PdfColor.fromHex('#E3EEE7'),
                        ),
                        children:
                            [
                                  'التاريخ',
                                  'رقم الإيصال',
                                  'المبلغ',
                                  'الحالة / البيان',
                                ]
                                .map(
                                  (label) => pw.Padding(
                                    padding: const pw.EdgeInsets.all(6),
                                    child: pw.Text(
                                      label,
                                      style: pw.TextStyle(
                                        font: bold,
                                        fontSize: 8,
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                      ),
                      ...profile.payments.map(
                        (payment) => pw.TableRow(
                          children: [
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(6),
                              child: pw.Text(
                                date.format(payment.paidAt),
                                style: pw.TextStyle(font: regular, fontSize: 7),
                                textDirection: pw.TextDirection.ltr,
                              ),
                            ),
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(6),
                              child: pw.Directionality(
                                textDirection: pw.TextDirection.ltr,
                                child: pw.Text(
                                  payment.receiptNo.replaceAll(
                                    RegExp(r'[\u0000-\u001F\u007F\u200B-\u200F\u202A-\u202E\u2060\u2066-\u2069\uFEFF]'),
                                    '',
                                  ).trim(),
                                  style: pw.TextStyle(font: regular, fontSize: 7),
                                ),
                              ),
                            ),
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(6),
                              child: pw.Directionality(
                                textDirection: pw.TextDirection.ltr,
                                child: pw.Text(
                                  '${payment.direction == 'credit' ? '+' : '-'} ${money.format(payment.amount)}',
                                  style: pw.TextStyle(font: regular, fontSize: 7),
                                ),
                              ),
                            ),
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(6),
                              child: pw.Text(
                                '${payment.status == 'reversed'
                                    ? 'معكوسة'
                                    : payment.status == 'void'
                                    ? 'ملغاة'
                                    : 'مسجلة'}${(payment.note ?? '').trim().isEmpty ? '' : '\n${payment.note ?? ''}'}',
                                style: pw.TextStyle(font: regular, fontSize: 7),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                pw.SizedBox(height: 16),
                pw.Text(
                  'يحتوي مجلد ملف المسافر على النسخ الأصلية من المستندات المتاحة في النظام.',
                  style: pw.TextStyle(font: regular, fontSize: 8, color: PdfColors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
    return document.save();
  }
}
