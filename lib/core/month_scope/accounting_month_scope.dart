import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Shared accounting-month context for the entire SWS workspace.
/// Dates are normalized to the first day of a month.
class AccountingMonthScope {
  AccountingMonthScope._();

  static DateTime _firstDay(DateTime value) =>
      DateTime(value.year, value.month);

  static final ValueNotifier<DateTime> selected = ValueNotifier<DateTime>(
    _firstDay(DateTime.now()),
  );

  static DateTime get start => _firstDay(selected.value);
  static DateTime get endExclusive => DateTime(start.year, start.month + 1);

  static void select(DateTime value) {
    final next = _firstDay(value);
    if (!sameMonth(selected.value, next)) selected.value = next;
  }

  static void shift(int delta) =>
      select(DateTime(start.year, start.month + delta));

  static bool contains(DateTime value) =>
      !value.isBefore(start) && value.isBefore(endExclusive);

  static bool sameMonth(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month;

  static const _months = <String>[
    'يناير',
    'فبراير',
    'مارس',
    'أبريل',
    'مايو',
    'يونيو',
    'يوليو',
    'أغسطس',
    'سبتمبر',
    'أكتوبر',
    'نوفمبر',
    'ديسمبر',
  ];

  static String label(DateTime value) =>
      '${_months[value.month - 1]} ${value.year}';
}

class AccountingMonthBar extends StatelessWidget {
  const AccountingMonthBar({super.key});

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<DateTime>(
    valueListenable: AccountingMonthScope.selected,
    builder: (context, month, _) => Material(
      color: const Color(0xFFF7F5EF),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 560;
          final controls = <Widget>[
            IconButton(
              tooltip: 'الشهر السابق',
              visualDensity: VisualDensity.compact,
              onPressed: () => AccountingMonthScope.shift(-1),
              icon: const Icon(Icons.chevron_right),
            ),
            Flexible(
              child: Text(
                AccountingMonthScope.label(month),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF174B3B),
                ),
              ),
            ),
            IconButton(
              tooltip: 'الشهر التالي',
              visualDensity: VisualDensity.compact,
              onPressed: () => AccountingMonthScope.shift(1),
              icon: const Icon(Icons.chevron_left),
            ),
          ];
          return Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(12, 5, 12, 5),
            child: compact
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.calendar_month_outlined,
                            size: 18,
                            color: Color(0xFF174B3B),
                          ),
                          SizedBox(width: 7),
                          Text(
                            'الفترة المحاسبية',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF52645C),
                            ),
                          ),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: controls,
                      ),
                      Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: TextButton.icon(
                          onPressed: () =>
                              AccountingMonthScope.select(DateTime.now()),
                          icon: const Icon(Icons.today, size: 16),
                          label: const Text('الشهر الحالي'),
                        ),
                      ),
                    ],
                  )
                : Row(
                    children: [
                      const Icon(
                        Icons.calendar_month_outlined,
                        size: 19,
                        color: Color(0xFF174B3B),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'الفترة المحاسبية',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF52645C),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ...controls,
                      const Spacer(),
                      TextButton.icon(
                        onPressed: () =>
                            AccountingMonthScope.select(DateTime.now()),
                        icon: const Icon(Icons.today, size: 16),
                        label: const Text('الشهر الحالي'),
                      ),
                    ],
                  ),
          );
        },
      ),
    ),
  );
}
