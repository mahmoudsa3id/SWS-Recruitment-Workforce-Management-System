import 'dart:async';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/di/injection.dart';
import '../../../core/printing/receipt_printer.dart';
import '../../../core/utils/traveler_folder_saver.dart' as folder_saver;
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/app_loading_skeleton.dart';
import '../domain/entities/traveler_profile.dart';
import '../../documents/domain/entities/traveler_document.dart';
import '../../documents/presentation/cubit/documents_cubit.dart';
import '../domain/entities/traveler_payment.dart';
import 'cubit/traveler_profile_cubit.dart';
import 'widgets/sales_person_field.dart';
import '../domain/usecases/export_traveler_file.dart';

class TravelerProfilePage extends StatelessWidget {
  const TravelerProfilePage({super.key, required this.travelerId, this.isHr = false});
  final String travelerId;
  final bool isHr;
  @override
  Widget build(BuildContext context) => MultiBlocProvider(
    providers: [
      BlocProvider(create: (_) => sl<TravelerProfileCubit>()..load(travelerId)),
      BlocProvider(create: (_) => sl<DocumentsCubit>()..load(travelerId)),
    ],
    child: _TravelerProfileView(travelerId: travelerId, isHr: isHr),
  );
}

class _TravelerProfileView extends StatefulWidget {
  const _TravelerProfileView({required this.travelerId, required this.isHr});
  final String travelerId;
  final bool isHr;

  @override
  State<_TravelerProfileView> createState() => _TravelerProfileViewState();
}

class _TravelerProfileViewState extends State<_TravelerProfileView> {
  String get travelerId => widget.travelerId;
  final TextEditingController _documentSearchController = TextEditingController();
  Timer? _documentSearchDebounce;
  String _documentSearchQuery = '';

  void _onDocumentSearchChanged(String value) {
    _documentSearchDebounce?.cancel();
    _documentSearchDebounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      setState(() => _documentSearchQuery = value.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _documentSearchDebounce?.cancel();
    _documentSearchController.dispose();
    super.dispose();
  }
  Future<void> _exportTravelerFile(
    BuildContext context,
    String travelerName,
  ) async {
    // Ask for the destination first. On web, the browser requires this picker
    // to be opened directly from a user gesture before long async work begins.
    String? destination;
    try {
      destination = await folder_saver.chooseDestination();
    } catch (_) {
      destination = null;
    }
    if (!context.mounted) return;
    if (destination == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'لم يتم اختيار مجلد للحفظ، أو أن المتصفح لا يدعم اختيار المجلدات. استخدم Chrome أو Edge عبر HTTPS أو localhost.',
          ),
        ),
      );
      return;
    }

    final result = await sl<ExportTravelerFile>()(travelerId);
    if (!context.mounted) return;
    String? error;
    Uint8List? bytes;
    result.fold((failure) => error = failure.message, (value) => bytes = value);
    if (error != null || bytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error ?? 'تعذر تكوين ملف المسافر.')),
      );
      return;
    }

    final safeTravelerName = travelerName
        .trim()
        .replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1F]'), '_')
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'[. ]+$'), '')
        .trim();
    final folderName = safeTravelerName.isEmpty ? 'ملف-المسافر' : safeTravelerName;

    try {
      final exportBytes = bytes;
      if (exportBytes == null || exportBytes.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ملف التصدير فارغ.')),
        );
        return;
      }
      final saved = await folder_saver.saveZipAsFolder(
        destination: destination,
        folderName: folderName,
        zipBytes: exportBytes,
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            saved
                ? 'تم حفظ مجلد "$folderName" وبداخله ملخص المسافر والمستندات.'
                : 'تعذر إنشاء المجلد. تحقق من صلاحيات الحفظ وحاول مرة أخرى.',
          ),
        ),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر حفظ مجلد المسافر: $e')),
        );
      }
    }
  }

  Future<void> _addPayment(
    BuildContext context,
    TravelerProfile profile,
  ) async {
    final amount = TextEditingController(), note = TextEditingController();
    var method = 'cash';
    final form = GlobalKey<FormState>();
    final accepted = await showDialog<bool>(
      context: context,
      builder: (d) => StatefulBuilder(
        builder: (d, setD) => AlertDialog(
          title: Text(widget.isHr ? 'طلب تسجيل دفعة' : 'تسجيل دفعة جديدة'),
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
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: note,
                    decoration: const InputDecoration(
                      labelText: 'البيان (اختياري)',
                    ),
                  ),
                ],
              ),
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
              child: Text(widget.isHr ? 'إرسال الطلب للأدمن' : 'تسجيل الدفعة'),
            ),
          ],
        ),
      ),
    );
    if (accepted != true || !context.mounted) return;
    if (widget.isHr) {
      try {
        await sl<SupabaseClient>().rpc('sws_create_financial_request', params: {
          'p_traveler_id': profile.traveler.id,
          'p_request_type': 'traveler_payment',
          'p_amount': double.parse(amount.text),
          'p_payment_method': method,
          'p_note': note.text.trim(),
        });
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم إرسال طلب العملية المالية للأدمن للمراجعة. لن يتغير الرصيد قبل الموافقة.')),
          );
        }
      } catch (e) {
        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر إرسال الطلب المالي: $e')),
        );
      }
      return;
    }
    final error = await context.read<TravelerProfileCubit>().addPayment(
      travelerId: profile.traveler.id,
      amount: double.parse(amount.text),
      method: method,
      note: note.text.trim(),
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error ?? 'تم تسجيل الدفعة وإنشاء الحركة المالية.'),
      ),
    );
    if (error == null || error.startsWith('تم تسجيل الدفعة، لكن')) {
      final state = context.read<TravelerProfileCubit>().state;
      if (state is TravelerProfileLoaded && state.profile.payments.isNotEmpty) {
        final latest = state.profile.payments.first;
        try {
          await ReceiptPrinter.printTravelerReceipt(
            receiptNo: latest.receiptNo,
            travelerName: state.profile.traveler.fullName,
            phone: state.profile.traveler.phone,
            amount: latest.amount,
            method: latest.method,
            date: latest.paidAt,
            status: latest.status,
            note: latest.note,
          );
        } catch (_) {
          if (context.mounted)
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'تم تسجيل الدفعة، لكن تعذرت الطباعة. استخدم أيقونة الطباعة من سجل الدفعات.',
                ),
              ),
            );
        }
      }
    }
  }

  Future<void> _chooseAvatar(BuildContext context) async {
    final file = await FilePicker.pickFile(type: FileType.custom, allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp']);
    if (file == null || !context.mounted) return;
    try {
      final bytes = await file.readAsBytes();
      final ext = (file.extension ?? '').toLowerCase();
      final mime = switch (ext) { 'jpg' || 'jpeg' => 'image/jpeg', 'png' => 'image/png', 'webp' => 'image/webp', _ => 'application/octet-stream' };
      final error = await context.read<TravelerProfileCubit>().setAvatar(fileName: file.name, mimeType: mime, bytes: Uint8List.fromList(bytes));
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error ?? 'تم تحديث صورة المسافر.')));
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر قراءة الصورة أو رفعها: $e')));
    }
  }

  Widget _travelerAvatar(String? path, {double radius = 34}) {
    if (path == null || path.trim().isEmpty) return CircleAvatar(radius: radius, backgroundColor: AppTheme.paleGreen, child: Icon(Icons.person_rounded, size: radius, color: AppTheme.green));
    return FutureBuilder<String>(
      future: Supabase.instance.client.storage.from('sws-private-documents').createSignedUrl(path, 300),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return CircleAvatar(radius: radius, backgroundColor: AppTheme.paleGreen, child: Icon(Icons.person_rounded, size: radius, color: AppTheme.green));
        return CircleAvatar(radius: radius, backgroundColor: AppTheme.paleGreen, backgroundImage: NetworkImage(snapshot.data!));
      },
    );
  }

  Future<void> _editProfile(
    BuildContext context,
    TravelerProfile profile,
  ) async {
    final traveler = profile.traveler;
    final profileCubit = context.read<TravelerProfileCubit>();
    final name = TextEditingController(text: traveler.fullName),
        phone = TextEditingController(text: traveler.phone),
        total = TextEditingController(
          text: traveler.agreementTotal.toStringAsFixed(2),
        ),
        country = TextEditingController(
          text: traveler.destinationCountry ?? '',
        ),
        sales = TextEditingController(text: traveler.salesPerson ?? '');
    final form = GlobalKey<FormState>();
    final accepted = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('تعديل بيانات المسافر'),
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
                      labelText: 'الاسم بالكامل *',
                    ),
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'الاسم مطلوب' : null,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: phone,
                    decoration: const InputDecoration(
                      labelText: 'رقم الهاتف *',
                    ),
                    validator: (v) => v == null || v.trim().isEmpty
                        ? 'رقم الهاتف مطلوب'
                        : null,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: total,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'إجمالي الاتفاق *',
                    ),
                    validator: (v) {
                      final n = double.tryParse(v ?? '');
                      return n == null || !n.isFinite || n < 0
                          ? 'مبلغ غير صحيح'
                          : null;
                    },
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: country,
                    decoration: const InputDecoration(labelText: 'الدولة'),
                  ),
                  const SizedBox(height: 10),
                  SalesPersonField(
                    controller: sales,
                    label: 'مسؤول المبيعات',
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(d, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () {
              if (form.currentState?.validate() == true) Navigator.pop(d, true);
            },
            child: const Text('حفظ التعديلات'),
          ),
        ],
      ),
    );
    if (accepted != true || !context.mounted) return;
    final error = await profileCubit.updateTraveler(
      fullName: name.text,
      phone: phone.text,
      agreementTotal: double.parse(total.text),
      country: country.text.trim().isEmpty ? null : country.text.trim(),
      salesPerson: sales.text.trim().isEmpty ? null : sales.text.trim(),
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(error ?? 'تم تحديث ملف المسافر.')));
  }

  Future<void> _stage(BuildContext context, String stage, bool value) async {
    final current = context.read<TravelerProfileCubit>().state;
    if (current is TravelerProfileLoaded) {
      final t = current.profile.traveler;
      if (value && stage == 'visa' && !t.inspected) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('لا يمكن نقل المسافر إلى التأشيرة قبل تسجيل الكشف.')));
        return;
      }
      if (value && stage == 'flight' && !t.visaIssued) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('لا يمكن إكمال الطيران قبل صدور التأشيرة.')));
        return;
      }
      if (value && stage == 'flight' && t.ticketBookingType == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('حدّد أولًا هل حجز التذكرة عن طريق الشركة أم حجز خارجي.')));
        return;
      }
      if (!value && stage == 'submitted' && (t.inspected || t.visaIssued || t.flightBooked)) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ارجع المراحل التالية أولًا قبل إلغاء مرحلة «قدم».')));
        return;
      }
      if (!value && stage == 'inspected' && (t.visaIssued || t.flightBooked)) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ألغِ مرحلة التأشيرة والطيران أولًا.')));
        return;
      }
      if (!value && stage == 'visa' && t.flightBooked) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ألغِ مرحلة الطيران أولًا.')));
        return;
      }
    }
    final error = await context.read<TravelerProfileCubit>().setStage(stage: stage, value: value);
    if (!context.mounted) return;
    if (error != null) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
  }

  static const _documentTypes = [
    'الصورة والباسبور',
    'التأشيرة',
    'إثبات التاريخ',
    'تذكرة الطيران',
    'مستندات أخرى',
  ];
  String _mime(String? ext) => switch ((ext ?? '').toLowerCase()) {
    'pdf' => 'application/pdf',
    'jpg' || 'jpeg' => 'image/jpeg',
    'png' => 'image/png',
    'webp' => 'image/webp',
    _ => 'application/octet-stream',
  };
  Future<void> _uploadDocument(BuildContext context, String type) async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png', 'webp'],
    );
    if (file == null || !context.mounted) return;
    late final List<int> bytes;
    try {
      bytes = await file.readAsBytes();
    } catch (_) {
      if (context.mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر قراءة الملف المحدد.')),
        );
      return;
    }
    if (!context.mounted) return;
    if (bytes.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('الملف المحدد فارغ.')));
      return;
    }
    final error = await context.read<DocumentsCubit>().upload(
      travelerId: travelerId,
      type: type,
      fileName: file.name,
      mimeType: _mime(file.extension),
      bytes: Uint8List.fromList(bytes),
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(error ?? 'تم رفع المستند بنجاح.')));
    if (error == null) await context.read<DocumentsCubit>().load(travelerId);
  }

  Future<void> _openDocument(BuildContext context, TravelerDocument doc) async {
    final url = await context.read<DocumentsCubit>().link(doc.storagePath);
    if (!context.mounted) return;
    if (url == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر إنشاء رابط آمن للمستند.')),
      );
      return;
    }
    final uri = Uri.tryParse(url);
    if (uri == null ||
        !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (context.mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('تعذر فتح المستند.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TravelerProfileCubit, TravelerProfileState>(
      builder: (context, state) {
        if (state is TravelerProfileInitial ||
            state is TravelerProfileLoading) {
          return const Scaffold(
            body: AppLoadingSkeleton(),
          );
        }
        if (state is TravelerProfileFailure) {
          return Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(24),
              child: ErrorPanel(
                message: state.message,
                onRetry: () =>
                    context.read<TravelerProfileCubit>().load(travelerId),
              ),
            ),
          );
        }

        final profile = (state as TravelerProfileLoaded).profile;
        final traveler = profile.traveler;
        return AppScaffold(
          title: 'ملف المسافر',
          actions: [
            if (!widget.isHr) IconButton(
              tooltip: 'تصدير ملف المسافر مع مستنداته',
              onPressed: () => _exportTravelerFile(context, traveler.fullName),
              icon: const Icon(Icons.folder_open_outlined),
            ),
            if (!widget.isHr) IconButton(
              tooltip: 'تعديل بيانات المسافر',
              onPressed: () => _editProfile(context, profile),
              icon: const Icon(Icons.edit_outlined),
            ),
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 12),
              child: FilledButton.icon(
                onPressed: () => _addPayment(context, profile),
                icon: Icon(widget.isHr ? Icons.send_rounded : Icons.add_card),
                label: Text(widget.isHr ? 'طلب عملية مالية' : 'إضافة دفعة'),
              ),
            ),
          ],
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppTheme.green, AppTheme.green2],
                  ),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Stack(children: [
                      _travelerAvatar(traveler.avatarPath, radius: 38),
                      if (!widget.isHr) PositionedDirectional(bottom: -2, end: -2, child: IconButton.filledTonal(
                        tooltip: 'تغيير صورة المسافر', onPressed: () => _chooseAvatar(context),
                        icon: const Icon(Icons.camera_alt_rounded, size: 16),
                        style: IconButton.styleFrom(backgroundColor: Colors.white, foregroundColor: AppTheme.green, minimumSize: const Size(30, 30), padding: EdgeInsets.zero),
                      )),
                    ]),
                    const SizedBox(width: 18),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(traveler.fullName, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Colors.white)),
                      const SizedBox(height: 6),
                      Text('${traveler.phone} • رقم الملف ${traveler.fileNo ?? '—'}', style: const TextStyle(color: Colors.white70)),
                      if (traveler.destinationCountry != null) Text('الوجهة: ${traveler.destinationCountry}', style: const TextStyle(color: Colors.white70)),
                      const SizedBox(height: 8),
                      Wrap(spacing: 8, runSpacing: 6, children: [
                        _stageBadge(traveler.currentStage),
                        if (traveler.salesPerson != null && traveler.salesPerson!.trim().isNotEmpty) _stageBadge('مسؤول: ${traveler.salesPerson}'),
                      ]),
                    ])),
                  ],
                ),
              ),
              if (profile.isCachedSnapshot)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(14),
                    child: Row(
                      children: [
                        Icon(Icons.cloud_off_outlined),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'تعرض هذه الصفحة آخر نسخة محفوظة محليًا. عمليات الدفع والتعديل تحتاج اتصالًا بالخادم.',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _metric('إجمالي الاتفاق', traveler.agreementTotal),
                  _metric('صافي التحصيل', profile.netPaid),
                  _metric('المتبقي', profile.remaining),
                ],
              ),
              const SizedBox(height: 24),
              const SectionTitle(
                'مراحل المسافر',
                subtitle: 'تحديث المرحلة يسجل في قاعدة البيانات وسجل المراجعة.',
              ),
              const SizedBox(height: 8),
              Card(
                child: Column(
                  children: [
                    SwitchListTile(
                      title: const Text('قدم'),
                      value: traveler.submitted,
                      onChanged: (value) => _stage(context, 'submitted', value),
                    ),
                    SwitchListTile(
                      title: const Text('كشف'),
                      value: traveler.inspected,
                      onChanged: (value) => _stage(context, 'inspected', value),
                    ),
                    SwitchListTile(
                      title: const Text('تأشيرة'),
                      value: traveler.visaIssued,
                      onChanged: (value) => _stage(context, 'visa', value),
                    ),
                    SwitchListTile(
                      title: const Text('طيران'),
                      value: traveler.flightBooked,
                      onChanged: (value) => _stage(context, 'flight', value),
                    ),
                  ],
                ),
              ),
              if (traveler.visaIssued && !traveler.flightBooked) ...[
                const SizedBox(height: 18),
                _TicketBookingCard(initialType: traveler.ticketBookingType, initialNote: traveler.ticketBookingNote),
              ],
              const SizedBox(height: 24),
              const SectionTitle('سجل الدفعات والحركات'),
              const SizedBox(height: 10),
              if (profile.payments.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(18),
                    child: Text('لا توجد دفعات مسجلة.'),
                  ),
                )
              else
                ...profile.payments.map(
                  (payment) => _paymentTile(
                    context,
                    payment,
                    traveler.fullName,
                    traveler.phone,
                  ),
                ),
              const SizedBox(height: 24),
              const SectionTitle('مستندات المسافر'),
              const SizedBox(height: 8),
              ..._documentSection(context),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _documentSection(BuildContext context) => [
    BlocBuilder<DocumentsCubit, DocumentsState>(
      builder: (context, state) {
        if (state is DocumentsInitial || state is DocumentsLoading)
          return const AppLoadingRows(rows: 2);
        if (state is DocumentsFailure)
          return ErrorPanel(
            message: state.message,
            onRetry: () => context.read<DocumentsCubit>().load(travelerId),
          );
        final docs = (state as DocumentsLoaded).items;
        final query = _documentSearchQuery;
        final matchingDocs = docs.where((doc) {
          if (query.isEmpty) return true;
          return doc.fileName.toLowerCase().contains(query) ||
              doc.type.toLowerCase().contains(query);
        }).toList(growable: false);
        return Column(
          children: [
            TextField(
              controller: _documentSearchController,
              onChanged: _onDocumentSearchChanged,
              decoration: InputDecoration(
                hintText: 'ابحث في مستندات المسافر بالاسم أو النوع...',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _documentSearchController.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'مسح البحث',
                        onPressed: () {
                          _documentSearchDebounce?.cancel();
                          _documentSearchController.clear();
                          setState(() => _documentSearchQuery = '');
                        },
                        icon: const Icon(Icons.close_rounded),
                      ),
              ),
            ),
            const SizedBox(height: 10),
            ..._documentTypes.map((type) {
            final items = matchingDocs
                .where((d) => d.type == type)
                .toList(growable: false);
            if (query.isNotEmpty && items.isEmpty) return const SizedBox.shrink();
            return Card(
              child: ExpansionTile(
                leading: const Icon(Icons.folder_outlined),
                title: Text(
                  type,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: Text('${items.length} ملف'),
                trailing: IconButton(
                  tooltip: 'رفع $type',
                  onPressed: () => _uploadDocument(context, type),
                  icon: const Icon(Icons.upload_file),
                ),
                children: items.isEmpty
                    ? [
                        const ListTile(
                          title: Text('لا توجد ملفات في هذا القسم.'),
                        ),
                      ]
                    : items
                          .map(
                            (doc) => ListTile(
                              leading: const Icon(Icons.description_outlined),
                              title: Text(doc.fileName),
                              subtitle: Text(
                                '${((doc.fileSize ?? 0) / 1024).toStringAsFixed(1)} KB • ${DateFormat('yyyy-MM-dd').format(doc.createdAt)}',
                              ),
                              trailing: IconButton(
                                tooltip: 'فتح المستند',
                                onPressed: () => _openDocument(context, doc),
                                icon: const Icon(Icons.open_in_new),
                              ),
                            ),
                          )
                          .toList(),
              ),
            );
          }).toList(),
          ],
        );
      },
    ),
  ];
  Widget _stageBadge(String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(color: Colors.white.withValues(alpha: .16), borderRadius: BorderRadius.circular(30)),
    child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
  );

  Widget _metric(String title, double value) => SizedBox(
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
              style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
            ),
          ],
        ),
      ),
    ),
  );
  Widget _paymentTile(
    BuildContext context,
    TravelerPayment p,
    String name,
    String phone,
  ) => Card(
    child: ListTile(
      leading: Icon(
        p.movementType == 'reversal' ? Icons.undo : Icons.receipt_long_outlined,
        color: p.direction == 'credit' ? AppTheme.green : Colors.red,
      ),
      title: Text(
        '${p.direction == 'credit' ? '+' : '−'} ${p.amount.toStringAsFixed(2)} ج.م',
        style: const TextStyle(fontWeight: FontWeight.w900),
      ),
      subtitle: Text(
        '${DateFormat('yyyy-MM-dd HH:mm').format(p.paidAt)} • ${p.method} • ${p.receiptNo}\n${p.note ?? ''}\n${p.status == 'posted'
            ? 'مسجلة'
            : p.status == 'reversed'
            ? 'معكوسة'
            : 'ملغاة'}',
      ),
      isThreeLine: true,
      trailing: IconButton(
        tooltip: 'طباعة الإيصال',
        icon: const Icon(Icons.print_outlined),
        onPressed: () => ReceiptPrinter.printTravelerReceipt(
          receiptNo: p.receiptNo,
          travelerName: name,
          phone: phone,
          amount: p.amount,
          method: p.method,
          date: p.paidAt,
          status: p.status,
          note: p.note,
        ),
      ),
    ),
  );
}


class _TicketBookingCard extends StatefulWidget {
  const _TicketBookingCard({required this.initialType, required this.initialNote});
  final String? initialType;
  final String? initialNote;
  @override
  State<_TicketBookingCard> createState() => _TicketBookingCardState();
}

class _TicketBookingCardState extends State<_TicketBookingCard> {
  late String? type = widget.initialType;
  late final TextEditingController note = TextEditingController(text: widget.initialNote ?? '');
  bool saving = false;
  @override
  void dispose() { note.dispose(); super.dispose(); }

  Future<void> _save() async {
    if (type == 'company' && note.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('اكتب ملاحظة حجز التذكرة من خلال الشركة.')));
      return;
    }
    setState(() => saving = true);
    final error = await context.read<TravelerProfileCubit>().setTicketBooking(type: type, note: note.text.trim());
    if (!mounted) return;
    setState(() => saving = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error ?? 'تم حفظ طريقة حجز التذكرة.')));
  }

  @override
  Widget build(BuildContext context) => Card(child: Padding(
    padding: const EdgeInsets.all(18),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SectionTitle('حجز تذكرة الطيران', subtitle: 'التأشيرة صدرت؛ حدّد طريقة حجز التذكرة قبل إكمال مرحلة الطيران.'),
      const SizedBox(height: 12),
      Wrap(spacing: 12, runSpacing: 8, children: [
        ChoiceChip(label: const Text('الحجز عن طريق الشركة'), selected: type == 'company', onSelected: (_) => setState(() => type = 'company')),
        ChoiceChip(label: const Text('حجز خارجي'), selected: type == 'external', onSelected: (_) => setState(() => type = 'external')),
      ]),
      if (type == 'company') ...[
        const SizedBox(height: 12),
        TextField(controller: note, minLines: 2, maxLines: 4, decoration: const InputDecoration(labelText: 'ملاحظة الحجز *', hintText: 'اكتب تفاصيل الحجز أو الموعد أو شركة الطيران')),
      ],
      const SizedBox(height: 12),
      Align(alignment: AlignmentDirectional.centerStart, child: FilledButton.icon(
        onPressed: saving || type == null ? null : _save,
        icon: saving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.save_outlined),
        label: Text(saving ? 'جارٍ الحفظ...' : 'حفظ اختيار التذكرة'),
      )),
    ]),
  ));
}
