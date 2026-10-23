import 'dart:async';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/di/injection.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../domain/entities/traveler.dart';
import 'cubit/travelers_cubit.dart';
import 'traveler_profile_page.dart';
import 'widgets/sales_person_field.dart';

class TravelersPage extends StatelessWidget {
  const TravelersPage({
    super.key,
    this.initialFilter = 'all',
    this.isHr = false,
  });
  final String initialFilter;
  final bool isHr;
  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => sl<TravelersCubit>()..load(),
    child: _TravelersView(initialFilter: initialFilter, isHr: isHr),
  );
}

class _TravelersView extends StatefulWidget {
  const _TravelersView({required this.initialFilter, required this.isHr});
  final String initialFilter;
  final bool isHr;
  @override
  State<_TravelersView> createState() => _TravelersViewState();
}

class _TravelersViewState extends State<_TravelersView> {
  final search = TextEditingController();
  late String _filter = widget.initialFilter;
  String? _salesFilter;
  Timer? _searchDebounce;

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      context.read<TravelersCubit>().load(query: value.trim());
    });
  }

  void _submitSearch(String value) {
    _searchDebounce?.cancel();
    context.read<TravelersCubit>().load(query: value.trim());
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    search.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final name = TextEditingController(),
        phone = TextEditingController(),
        total = TextEditingController(text: '0'),
        country = TextEditingController(),
        sales = TextEditingController();
    final form = GlobalKey<FormState>();
    PlatformFile? avatarFile;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (d) => StatefulBuilder(
        builder: (d, setD) => AlertDialog(
          title: const Text('إنشاء ملف مسافر'),
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
                      validator: (v) => v == null || v.trim().isEmpty
                          ? 'اسم المسافر مطلوب'
                          : null,
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: phone,
                      keyboardType: TextInputType.phone,
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
                        labelText: 'إجمالي الاتفاق (ج.م)',
                      ),
                      validator: (v) {
                        final n = double.tryParse(v ?? '');
                        return n == null || !n.isFinite || n < 0
                            ? 'أدخل مبلغًا صحيحًا'
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
                      label: 'تبع مين؟ مسؤول المبيعات',
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final picked = await FilePicker.pickFile(
                          type: FileType.custom,
                          allowedExtensions: const [
                            'jpg',
                            'jpeg',
                            'png',
                            'webp',
                          ],
                        );
                        if (picked != null) setD(() => avatarFile = picked);
                      },
                      icon: const Icon(Icons.add_a_photo_outlined),
                      label: Text(
                        avatarFile == null
                            ? 'إضافة صورة بروفايل (اختياري)'
                            : 'الصورة: ${avatarFile!.name}',
                      ),
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
                if (form.currentState?.validate() == true) {
                  Navigator.pop(d, true);
                }
              },
              child: const Text('إنشاء الملف'),
            ),
          ],
        ),
      ),
    );
    if (accepted != true || !mounted) return;
    final cubit = context.read<TravelersCubit>();
    final error = await cubit.create(
      fullName: name.text,
      phone: phone.text,
      agreementTotal: double.parse(total.text),
      country: country.text.trim().isEmpty ? null : country.text.trim(),
      salesPerson: sales.text.trim().isEmpty ? null : sales.text.trim(),
    );
    if (!mounted) return;
    if (error != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    String message = 'تم إنشاء ملف المسافر.';
    final newId = cubit.lastCreatedTravelerId;
    if (avatarFile != null && newId != null) {
      try {
        final ext = (avatarFile!.extension ?? '').toLowerCase();
        final mime = switch (ext) {
          'jpg' || 'jpeg' => 'image/jpeg',
          'png' => 'image/png',
          'webp' => 'image/webp',
          _ => 'application/octet-stream',
        };
        final bytes = await avatarFile!.readAsBytes();
        final avatarError = await cubit.setAvatarForTraveler(
          travelerId: newId,
          fileName: avatarFile!.name,
          mimeType: mime,
          bytes: Uint8List.fromList(bytes),
        );
        if (avatarError != null) {
          message = 'تم إنشاء المسافر، لكن تعذر رفع صورته: $avatarError';
        }
      } catch (e) {
        message = 'تم إنشاء المسافر، لكن تعذر قراءة الصورة: $e';
      }
    }
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
    await cubit.refresh();
  }

  Future<void> _delete(BuildContext context, Traveler traveler) async {
    final reason = TextEditingController();
    final accepted = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('حذف المسافر نهائيًا'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'سيتم حذف ${traveler.fullName} ومستنداته وحركاته المالية المرتبطة. سيُحفظ سجل تدقيق بالبيانات المحذوفة. لا يمكن تنفيذ العملية إذا كانت هناك حركة في شهر مقفول.',
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
            onPressed: () => Navigator.pop(d, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(d, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('حذف نهائي'),
          ),
        ],
      ),
    );
    if (accepted != true || !mounted) return;
    if (reason.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('اكتب سبب الحذف.')));
      return;
    }
    // ignore: use_build_context_synchronously
    final outcome = await context.read<TravelersCubit>().deleteTraveler(
      travelerId: traveler.id,
      reason: reason.text.trim(),
    );
    if (!mounted) return;
    final error = outcome.$1;
    final filesPending = outcome.$2;
    final message =
        error ??
        (filesPending
            ? 'تم حذف بيانات المسافر والحركات. بعض ملفات Storage ما زالت بانتظار إعادة المحاولة.'
            : 'تم حذف المسافر ومستنداته وحركاته المالية.');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 6)),
    );
    if (error == null) await context.read<TravelersCubit>().refresh();
  }

  @override
  Widget build(BuildContext context) => AppScaffold(
    title: widget.isHr ? 'متابعة المسافرين — HR' : 'المسافرون',
    actions: widget.isHr
        ? const []
        : [
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 12),
              child: FilledButton.icon(
                onPressed: _create,
                icon: const Icon(Icons.person_add_alt_1),
                label: const Text('مسافر جديد'),
              ),
            ),
          ],
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionTitle(
            widget.isHr ? 'متابعة ملفات السفر' : 'إدارة المسافرين',
            subtitle: widget.isHr
                ? 'متابعة المراحل والمستندات فقط. لا توجد صلاحيات مالية.'
                : 'تابع مراحل السفر والتحصيل والموظف المسؤول من مكان واحد.',
          ),
          const SizedBox(height: 16),
          TextField(
            controller: search,
            onChanged: _onSearchChanged,
            onSubmitted: _submitSearch,
            decoration: InputDecoration(
              hintText: 'ابحث بالاسم أو الهاتف أو رقم الملف...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: IconButton(
                onPressed: () {
                  search.clear();
                  _submitSearch('');
                },
                icon: const Icon(Icons.close_rounded),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: BlocBuilder<TravelersCubit, TravelersState>(
              builder: (context, state) {
                if (state is TravelersInitial || state is TravelersLoading) {
                  return const _TravelerListSkeleton();
                }
                if (state is TravelersFailure) {
                  return ErrorPanel(
                    message: state.message,
                    onRetry: () =>
                        context.read<TravelersCubit>().load(query: search.text),
                  );
                }
                final all = (state as TravelersLoaded).items;
                final uninspected = all
                    .where(
                      (t) => !t.inspected && !t.visaIssued && !t.flightBooked,
                    )
                    .length;
                final fullyPaid = all.where((t) => t.isFullyPaid).length;
                final debts = all.where((t) => t.remaining > .009).length;
                final salesNamesByKey = <String, String>{};
                for (final traveler in all) {
                  final name = traveler.salesPerson?.trim() ?? '';
                  if (name.isNotEmpty) {
                    salesNamesByKey.putIfAbsent(name.toLowerCase(), () => name);
                  }
                }
                final salesPeople = salesNamesByKey.values.toList()
                  ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
                // A search/refresh can temporarily remove the selected person from
                // this result page. Never pass a stale value to DropdownButton.
                final activeSalesFilter =
                    salesPeople.any((name) => name == _salesFilter)
                    ? _salesFilter
                    : null;
                final filtered = all
                    .where((t) {
                      if (activeSalesFilter != null &&
                          t.salesPerson?.trim() != activeSalesFilter) {
                        return false;
                      }
                      switch (_filter) {
                        case 'uninspected':
                          return !t.inspected &&
                              !t.visaIssued &&
                              !t.flightBooked;
                        case 'fullyPaid':
                          return t.isFullyPaid;
                        case 'debts':
                          return t.remaining > .009;
                        case 'new':
                          return !t.submitted &&
                              !t.inspected &&
                              !t.visaIssued &&
                              !t.flightBooked;
                        case 'submitted':
                          return t.submitted &&
                              !t.inspected &&
                              !t.visaIssued &&
                              !t.flightBooked;
                        case 'inspected':
                          return t.inspected &&
                              !t.visaIssued &&
                              !t.flightBooked;
                        case 'visa':
                          return t.visaIssued && !t.flightBooked;
                        case 'flight':
                          return t.flightBooked;
                        default:
                          return true;
                      }
                    })
                    .toList(growable: false);
                return SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      LayoutBuilder(
                        builder: (context, c) {
                          final columns = c.maxWidth < 540
                              ? 2
                              : c.maxWidth < 900
                              ? 3
                              : 4;
                          return GridView.count(
                            crossAxisCount: columns,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                            childAspectRatio: c.maxWidth < 540 ? 1.9 : 2.15,
                            children: [
                              _summaryCard(
                                'كل المسافرين',
                                all.length,
                                Icons.groups_2_rounded,
                                'all',
                                const Color(0xFF176B50),
                              ),
                              _summaryCard(
                                'لم يتم الكشف',
                                uninspected,
                                Icons.medical_services_outlined,
                                'uninspected',
                                const Color(0xFFB7791F),
                              ),
                              _summaryCard(
                                'سددوا بالكامل',
                                fullyPaid,
                                Icons.verified_rounded,
                                'fullyPaid',
                                const Color(0xFF287A55),
                              ),
                              _summaryCard(
                                'عليهم مستحقات',
                                debts,
                                Icons.account_balance_wallet_outlined,
                                'debts',
                                const Color(0xFFB54747),
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 14),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _filterChip('الكل', 'all'),
                            _filterChip('جديد', 'new'),
                            _filterChip('قدم', 'submitted'),
                            _filterChip('بانتظار الكشف', 'uninspected'),
                            _filterChip('بانتظار التأشيرة', 'inspected'),
                            _filterChip('بانتظار التذكرة', 'visa'),
                            _filterChip('تم حجز التذكرة', 'flight'),
                            _filterChip('سددوا بالكامل', 'fullyPaid'),
                            _filterChip('عليهم فلوس', 'debts'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Icon(
                            Icons.support_agent_rounded,
                            color: AppTheme.muted,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'مسؤول المبيعات',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: DropdownButton<String?>(
                              isExpanded: true,
                              value: activeSalesFilter,
                              hint: const Text('كل مسؤولي المبيعات'),
                              underline: const SizedBox.shrink(),
                              items: [
                                const DropdownMenuItem<String?>(
                                  value: null,
                                  child: Text('كل مسؤولي المبيعات'),
                                ),
                                ...salesPeople.map(
                                  (name) => DropdownMenuItem<String?>(
                                    value: name,
                                    child: Text(
                                      name,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                              ],
                              onChanged: (value) =>
                                  setState(() => _salesFilter = value),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'قائمة المسافرين',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          Text(
                            '${filtered.length} مسافر',
                            style: const TextStyle(
                              color: AppTheme.muted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (filtered.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 32),
                          child: Center(
                            child: Text('لا يوجد مسافرون في هذا التصنيف.'),
                          ),
                        )
                      else
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
                          itemBuilder: (context, index) =>
                              _tile(context, filtered[index]),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    ),
  );

  Widget _summaryCard(
    String label,
    int value,
    IconData icon,
    String filter,
    Color color,
  ) => Material(
    color: _filter == filter ? color.withValues(alpha: .10) : Colors.white,
    borderRadius: BorderRadius.circular(16),
    child: InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => setState(() => _filter = filter),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _filter == filter
                ? color.withValues(alpha: .55)
                : AppTheme.border,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color.withValues(alpha: .10),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '$value',
                    style: TextStyle(
                      fontSize: 23,
                      fontWeight: FontWeight.w900,
                      color: color,
                    ),
                  ),
                  Text(
                    label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppTheme.muted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _filterChip(String label, String value) => Padding(
    padding: const EdgeInsetsDirectional.only(end: 7),
    child: ChoiceChip(
      label: Text(label),
      selected: _filter == value,
      onSelected: (_) => setState(() => _filter = value),
    ),
  );

  Widget _avatar(String? path) {
    const radius = 25.0;
    if (path == null || path.trim().isEmpty) {
      return const CircleAvatar(
        radius: radius,
        backgroundColor: AppTheme.paleGreen,
        child: Icon(Icons.person_rounded, color: AppTheme.green),
      );
    }
    return FutureBuilder<String>(
      future: Supabase.instance.client.storage
          .from('sws-private-documents')
          .createSignedUrl(path, 300),
      builder: (context, snapshot) => CircleAvatar(
        radius: radius,
        backgroundColor: AppTheme.paleGreen,
        backgroundImage: snapshot.hasData ? NetworkImage(snapshot.data!) : null,
        child: snapshot.hasData
            ? null
            : const Icon(Icons.person_rounded, color: AppTheme.green),
      ),
    );
  }

  Widget _tile(BuildContext context, Traveler t) => Card(
    child: InkWell(
      onTap: () {
        // Capture the Cubit before navigation. The list item's BuildContext may
        // be deactivated by the time the pushed profile route is popped.
        final travelersCubit = this.context.read<TravelersCubit>();
        Navigator.of(context)
            .push(
              MaterialPageRoute(
                builder: (_) =>
                    TravelerProfilePage(travelerId: t.id, isHr: widget.isHr),
              ),
            )
            .then((_) {
              if (mounted && !travelersCubit.isClosed) travelersCubit.refresh();
            });
      },
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(14, 12, 10, 12),
        child: Row(
          children: [
            _avatar(t.avatarPath),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t.fullName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        t.phone,
                        style: const TextStyle(
                          color: AppTheme.muted,
                          fontSize: 12,
                        ),
                      ),
                      if (t.salesPerson != null &&
                          t.salesPerson!.trim().isNotEmpty)
                        Text(
                          'مسؤول: ${t.salesPerson}',
                          style: const TextStyle(
                            color: AppTheme.muted,
                            fontSize: 11,
                          ),
                        ),
                      if (t.destinationCountry != null &&
                          t.destinationCountry!.trim().isNotEmpty)
                        Text(
                          t.destinationCountry!,
                          style: const TextStyle(
                            color: AppTheme.muted,
                            fontSize: 11,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 7),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      _statusPill(
                        t.currentStage,
                        t.flightBooked
                            ? const Color(0xFF287A55)
                            : t.visaIssued
                            ? const Color(0xFF6B5BB5)
                            : t.inspected
                            ? const Color(0xFFB7791F)
                            : const Color(0xFF176B50),
                      ),
                      if (t.isFullyPaid)
                        _statusPill('مسدد بالكامل', const Color(0xFF287A55)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${t.remaining.toStringAsFixed(0)} ج.م',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: t.remaining > .009
                        ? const Color(0xFFB54747)
                        : const Color(0xFF287A55),
                  ),
                ),
                const Text(
                  'المتبقي',
                  style: TextStyle(fontSize: 10, color: AppTheme.muted),
                ),
              ],
            ),
            const SizedBox(width: 4),
            if (t.remaining > .009)
              IconButton(
                tooltip: 'اتصال بالمسافر بسبب المبلغ المتبقي',
                onPressed: () async {
                  final uri = Uri(scheme: 'tel', path: t.phone.trim());
                  if (!await launchUrl(
                        uri,
                        mode: LaunchMode.externalApplication,
                      ) &&
                      context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'لا يوجد تطبيق اتصال يدعم هذا الرقم على هذا الجهاز.',
                        ),
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.call_rounded, color: AppTheme.green3),
              ),
            PopupMenuButton<String>(
              tooltip: 'خيارات المسافر',
              onSelected: (value) {
                if (!widget.isHr && value == 'delete') _delete(context, t);
                if (value == 'profile') {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => TravelerProfilePage(
                        travelerId: t.id,
                        isHr: widget.isHr,
                      ),
                    ),
                  );
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'profile',
                  child: ListTile(
                    dense: true,
                    leading: Icon(Icons.person_outline),
                    title: Text('فتح الملف'),
                  ),
                ),
                if (!widget.isHr)
                  const PopupMenuItem(
                    value: 'delete',
                    child: ListTile(
                      dense: true,
                      leading: Icon(Icons.delete_outline, color: Colors.red),
                      title: Text('حذف المسافر'),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    ),
  );

  Widget _statusPill(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .10),
      borderRadius: BorderRadius.circular(30),
    ),
    child: Text(
      label,
      style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w800),
    ),
  );
}

class _TravelerListSkeleton extends StatelessWidget {
  const _TravelerListSkeleton();
  @override
  Widget build(BuildContext context) => ListView(
    padding: EdgeInsets.zero,
    children: [
      Wrap(
        spacing: 10,
        runSpacing: 10,
        children: List.generate(
          4,
          (_) => Container(
            width: 190,
            height: 78,
            decoration: BoxDecoration(
              color: const Color(0xFFE9EFEB),
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ),
      const SizedBox(height: 16),
      ...List.generate(
        5,
        (_) => Container(
          margin: const EdgeInsets.only(bottom: 9),
          height: 94,
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: AppTheme.border),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(radius: 24, backgroundColor: Color(0xFFE9EFEB)),
                SizedBox(width: 14),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SkeletonBar(width: 180),
                      SizedBox(height: 10),
                      _SkeletonBar(width: 120),
                      SizedBox(height: 10),
                      _SkeletonBar(width: 220),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ],
  );
}

class _SkeletonBar extends StatelessWidget {
  const _SkeletonBar({required this.width});
  final double width;
  @override
  Widget build(BuildContext context) => Container(
    width: width,
    height: 8,
    decoration: BoxDecoration(
      color: const Color(0xFFE9EFEB),
      borderRadius: BorderRadius.circular(8),
    ),
  );
}
