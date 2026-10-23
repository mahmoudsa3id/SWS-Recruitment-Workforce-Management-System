import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/di/injection.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/month_scope/accounting_month_scope.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/app_loading_skeleton.dart';
import '../../travelers/presentation/travelers_page.dart';
import '../../finance/presentation/financial_movements_page.dart';
import '../../finance/presentation/financial_requests_page.dart';
import '../../expenses/presentation/expenses_page.dart';
import '../../payroll/presentation/payroll_page.dart';
import '../../monthly_closing/presentation/monthly_closing_page.dart';
import '../../documents/presentation/documents_page.dart';
import '../../reports/presentation/reports_page.dart';
import '../../settings/presentation/settings_page.dart';
import '../../audit/presentation/audit_page.dart';
import 'cubit/dashboard_cubit.dart';
import 'dashboard_charts.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key, required this.onSignOut, this.isHr = false});
  final Future<void> Function() onSignOut;
  final bool isHr;
  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  int index = 0;
  String travelerFilter = 'all';
  late List<Widget> pages;
  @override
  void initState() {
    super.initState();
    pages = _buildPages();
    AccountingMonthScope.selected.addListener(_onMonthChanged);
  }

  List<Widget> _buildPages() {
    final m =
        '${AccountingMonthScope.start.year}-${AccountingMonthScope.start.month}';
    if (widget.isHr) {
      return [TravelersPage(key: ValueKey('hr-travelers-$m'), isHr: true)];
    }
    return [
      _OverviewPage(
        key: ValueKey('overview-$m'),
        onSignOut: widget.onSignOut,
        onNavigate: (i) => setState(() => index = i),
        onOpenTravelerFilter: (filter) {
          setState(() {
            travelerFilter = filter;
            index = 1;
            pages = _buildPages();
          });
        },
      ),
      TravelersPage(
        key: ValueKey('travelers-$m-$travelerFilter'),
        initialFilter: travelerFilter,
      ),
      FinancialMovementsPage(key: ValueKey('finance-$m')),
      ExpensesPage(key: ValueKey('expenses-$m')),
      PayrollPage(key: ValueKey('payroll-$m')),
      MonthlyClosingPage(key: ValueKey('closing-$m')),
      DocumentsPage(key: ValueKey('documents-$m')),
      ReportsPage(key: ValueKey('reports-$m')),
      SettingsPage(key: ValueKey('settings-$m')),
      AuditPage(key: ValueKey('audit-$m')),
      FinancialRequestsPage(key: ValueKey('financial-requests-$m')),
    ];
  }

  void _onMonthChanged() {
    if (!mounted) return;
    setState(() => pages = _buildPages());
  }

  @override
  void dispose() {
    AccountingMonthScope.selected.removeListener(_onMonthChanged);
    super.dispose();
  }

  static const destinations = <NavigationRailDestination>[
    NavigationRailDestination(
      icon: Icon(Icons.dashboard_outlined),
      selectedIcon: Icon(Icons.dashboard),
      label: Text('الرئيسية'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.people_outline),
      selectedIcon: Icon(Icons.people),
      label: Text('المسافرون'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.account_balance_wallet_outlined),
      selectedIcon: Icon(Icons.account_balance_wallet),
      label: Text('الحركات المالية'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.receipt_long_outlined),
      selectedIcon: Icon(Icons.receipt_long),
      label: Text('المصروفات'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.badge_outlined),
      selectedIcon: Icon(Icons.badge),
      label: Text('المرتبات'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.lock_clock_outlined),
      selectedIcon: Icon(Icons.lock_clock),
      label: Text('الإقفال الشهري'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.folder_outlined),
      selectedIcon: Icon(Icons.folder),
      label: Text('المستندات'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.assessment_outlined),
      selectedIcon: Icon(Icons.assessment),
      label: Text('التقارير'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.settings_outlined),
      selectedIcon: Icon(Icons.settings),
      label: Text('الإعدادات'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.history),
      selectedIcon: Icon(Icons.history),
      label: Text('سجل المراجعة'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.fact_check_outlined),
      selectedIcon: Icon(Icons.fact_check),
      label: Text('طلبات العمليات المالية'),
    ),
  ];
  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 1100;
    if (widget.isHr) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('SWS | موارد بشرية'),
          actions: [
            IconButton(
              tooltip: 'تسجيل الخروج',
              onPressed: widget.onSignOut,
              icon: const Icon(Icons.logout),
            ),
          ],
        ),
        body: IndexedStack(index: 0, children: pages),
      );
    }
    return Scaffold(
      body: Row(
        children: [
          if (wide)
            Container(
              width: 264,
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(left: BorderSide(color: AppTheme.border)),
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 24, 18, 22),
                    child: Row(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.topRight,
                              end: Alignment.bottomLeft,
                              colors: [AppTheme.green2, AppTheme.green],
                            ),
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: const Icon(
                            Icons.account_balance_rounded,
                            color: Colors.white,
                            size: 25,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'SWS',
                                style: TextStyle(
                                  color: AppTheme.green,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.1,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'شمس الإبداع',
                                style: TextStyle(
                                  color: AppTheme.muted,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: AppTheme.border),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(22, 18, 22, 10),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        'القائمة الرئيسية',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppTheme.muted,
                          letterSpacing: .3,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: NavigationRail(
                      backgroundColor: Colors.white,
                      selectedIndex: index,
                      onDestinationSelected: (i) => setState(() => index = i),
                      extended: true,
                      minWidth: 80,
                      minExtendedWidth: 264,
                      groupAlignment: -1,
                      useIndicator: true,
                      scrollable: true,
                      destinations: destinations,
                    ),
                  ),
                  const Divider(height: 1, color: AppTheme.border),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.paleGreen,
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: const Row(
                        children: [
                          Icon(
                            Icons.verified_user_outlined,
                            color: AppTheme.green3,
                            size: 19,
                          ),
                          SizedBox(width: 9),
                          Expanded(
                            child: Text(
                              'وصول آمن للإدارة',
                              style: TextStyle(
                                color: AppTheme.green,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Icon(Icons.circle, color: AppTheme.green3, size: 7),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: IndexedStack(index: index, children: pages),
          ),
        ],
      ),
      bottomNavigationBar: wide
          ? null
          : NavigationBar(
              selectedIndex: index <= 3 ? index : 4,
              onDestinationSelected: (i) {
                if (i < 4) {
                  setState(() => index = i);
                  return;
                }
                showModalBottomSheet<void>(
                  context: context,
                  builder: (ctx) => SafeArea(
                    child: Wrap(
                      children: [
                        _menuItem(ctx, 4, 'المرتبات', Icons.badge_outlined),
                        _menuItem(
                          ctx,
                          5,
                          'الإقفال الشهري',
                          Icons.lock_clock_outlined,
                        ),
                        _menuItem(ctx, 6, 'المستندات', Icons.folder_outlined),
                        _menuItem(
                          ctx,
                          7,
                          'التقارير',
                          Icons.assessment_outlined,
                        ),
                        _menuItem(ctx, 8, 'الإعدادات', Icons.settings_outlined),
                        _menuItem(ctx, 9, 'سجل المراجعة', Icons.history),
                        _menuItem(
                          ctx,
                          10,
                          'طلبات العمليات المالية',
                          Icons.fact_check_outlined,
                        ),
                      ],
                    ),
                  ),
                );
              },
              labelBehavior:
                  NavigationDestinationLabelBehavior.onlyShowSelected,
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.dashboard_outlined),
                  label: 'الرئيسية',
                ),
                NavigationDestination(
                  icon: Icon(Icons.people_outline),
                  label: 'المسافرون',
                ),
                NavigationDestination(
                  icon: Icon(Icons.account_balance_wallet_outlined),
                  label: 'المالية',
                ),
                NavigationDestination(
                  icon: Icon(Icons.receipt_long_outlined),
                  label: 'المصروفات',
                ),
                NavigationDestination(icon: Icon(Icons.menu), label: 'المزيد'),
              ],
            ),
    );
  }

  Widget _menuItem(
    BuildContext context,
    int value,
    String title,
    IconData icon,
  ) => ListTile(
    leading: Icon(icon),
    title: Text(title),
    onTap: () {
      Navigator.pop(context);
      setState(() => index = value);
    },
  );
}

class _OverviewPage extends StatelessWidget {
  const _OverviewPage({
    super.key,
    required this.onSignOut,
    required this.onNavigate,
    required this.onOpenTravelerFilter,
  });
  final Future<void> Function() onSignOut;
  final ValueChanged<int> onNavigate;
  final ValueChanged<String> onOpenTravelerFilter;
  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => sl<DashboardCubit>()..load(),
    child: Builder(
      builder: (context) => AppScaffold(
        title: 'لوحة التحكم',
        actions: [
          IconButton(
            tooltip: 'تحديث',
            onPressed: () => context.read<DashboardCubit>().load(),
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'تسجيل الخروج',
            onPressed: () => _confirmLogout(context, onSignOut),
            icon: const Icon(Icons.logout),
          ),
        ],
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Container(
              padding: const EdgeInsets.all(30),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                  colors: [AppTheme.green, AppTheme.green2, Color(0xFF2A705A)],
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.green.withValues(alpha: .12),
                    blurRadius: 26,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'مرحبًا بك في SWS',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'نظام إدارة المسافرين والحسابات لشركة شمس الإبداع',
                    style: TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            BlocBuilder<DashboardCubit, DashboardState>(
              builder: (context, state) {
                if (state is DashboardLoading || state is DashboardInitial) {
                  return const SizedBox(
                    height: 420,
                    child: AppLoadingSkeleton(),
                  );
                }
                if (state is DashboardFailure) {
                  return ErrorPanel(
                    message: state.message,
                    onRetry: () => context.read<DashboardCubit>().load(),
                  );
                }

                final s = (state as DashboardLoaded).summary;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final width = constraints.maxWidth;
                        final columns = width < 600
                            ? 2
                            : width < 1000
                            ? 3
                            : 4;

                        final metrics = <Widget>[
                          _Metric(
                            'المسافرون النشطون',
                            '${s.totalTravelersCount}',
                            Icons.people_alt_outlined,
                          ),
                          _Metric(
                            'إجمالي الاتفاقات',
                            '${s.travelerAgreementTotal.toStringAsFixed(0)} ج.م',
                            Icons.description_outlined,
                          ),
                          _Metric(
                            'إجمالي المحصّل',
                            '${s.travelerPaidTotal.toStringAsFixed(0)} ج.م',
                            Icons.payments_outlined,
                          ),
                          _Metric(
                            'إجمالي المتبقي على المسافرين',
                            '${s.travelerRemainingTotal.toStringAsFixed(0)} ج.م',
                            Icons.account_balance_wallet_outlined,
                            accent: AppTheme.gold,
                          ),

                          _Metric(
                            'مسافرون سددوا بالكامل',
                            '${s.travelersFullyPaid}',
                            Icons.verified_outlined,
                            onTap: () => onOpenTravelerFilter('fullyPaid'),
                          ),
                          _Metric(
                            'مسافرون لم يتم الكشف عنهم',
                            '${s.stageNew + s.stageSubmitted}',
                            Icons.medical_services_outlined,
                            accent: AppTheme.gold,
                            onTap: () => onOpenTravelerFilter('uninspected'),
                          ),
                          _Metric(
                            'مسافرون عليهم مستحقات',
                            '${s.travelersWithBalance}',
                            Icons.money_off_outlined,
                            accent: AppTheme.danger,
                            onTap: () => onOpenTravelerFilter('debts'),
                          ),
                          _Metric(
                            'تحصيلات الشهر',
                            '${s.totalCollections.toStringAsFixed(0)} ج.م',
                            Icons.trending_up_rounded,
                          ),
                          _Metric(
                            'الإيرادات العامة',
                            '${s.generalRevenue.toStringAsFixed(0)} ج.م',
                            Icons.add_chart_rounded,
                          ),
                          _Metric(
                            'مصروفات المكتب',
                            '${s.officeExpenses.toStringAsFixed(0)} ج.م',
                            Icons.receipt_long_outlined,
                          ),
                          _Metric(
                            'المرتبات المدفوعة',
                            '${s.payrollPaid.toStringAsFixed(0)} ج.م',
                            Icons.badge_outlined,
                          ),
                          _Metric(
                            'رصيد الخزنة',
                            '${s.cashBalance.toStringAsFixed(0)} ج.م',
                            Icons.savings_outlined,
                            accent: AppTheme.green3,
                          ),
                          _Metric(
                            'موظفو الشهر',
                            '${s.employeeCount}',
                            Icons.groups_2_outlined,
                          ),
                        ];

                        return GridView.count(
                          crossAxisCount: columns,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                          childAspectRatio: width < 400
                              ? 0.95
                              : width < 600
                              ? 1.05
                              : width < 1000
                              ? 1.2
                              : 1.4,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          children: metrics,
                        );
                      },
                    ),
                    const SizedBox(height: 22),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final wide = constraints.maxWidth >= 860;
                        final balance = DashboardPanel(
                          title: 'الموقف المالي للمسافرين',
                          subtitle:
                              'المدفوع والمتبقي من إجمالي الاتفاقات الحالية',
                          child: BalanceDonut(
                            paid: s.travelerPaidTotal,
                            remaining: s.travelerRemainingTotal,
                            total: s.travelerAgreementTotal,
                          ),
                        );
                        final stages = DashboardPanel(
                          title: 'توزيع مراحل المسافرين',
                          subtitle:
                              'كل مسافر يظهر في المرحلة الأبعد التي وصل إليها',
                          child: StageDonut(summary: s),
                        );

                        if (!wide) {
                          return Column(
                            children: [
                              balance,
                              const SizedBox(height: 14),
                              stages,
                            ],
                          );
                        }

                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: balance),
                            const SizedBox(width: 14),
                            Expanded(child: stages),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 14),
                    DashboardPanel(
                      title: 'حركة الإيرادات والمصروفات',
                      subtitle: 'آخر 6 أشهر حتى شهر المحاسبة المحدد',
                      child: CashflowBarChart(points: s.monthlyTrend),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 24),
            const SectionTitle('الوصول السريع'),
            const SizedBox(height: 14),
            Wrap(
              spacing: 14,
              runSpacing: 14,
              children: [
                _QuickCard(
                  icon: Icons.people_alt_outlined,
                  title: 'إدارة المسافرين',
                  subtitle: 'ملفات ودفعات ومستندات',
                  onTap: () => onNavigate(1),
                ),
                _QuickCard(
                  icon: Icons.account_balance_wallet_outlined,
                  title: 'الحركات المالية',
                  subtitle: 'كل حركات الخزنة',
                  onTap: () => onNavigate(2),
                ),
                _QuickCard(
                  icon: Icons.receipt_long_outlined,
                  title: 'مصروفات المكتب',
                  subtitle: 'تسجيل ومراجعة المصروفات',
                  onTap: () => onNavigate(3),
                ),
                _QuickCard(
                  icon: Icons.badge_outlined,
                  title: 'المرتبات',
                  subtitle: 'الاستحقاقات والمدفوعات',
                  onTap: () => onNavigate(4),
                ),
                _QuickCard(
                  icon: Icons.lock_clock_outlined,
                  title: 'الإقفال الشهري',
                  subtitle: 'الأرشيف وإعادة الفتح',
                  onTap: () => onNavigate(5),
                ),
                _QuickCard(
                  icon: Icons.folder_outlined,
                  title: 'مستندات المسافرين',
                  subtitle: 'أرشيف المستندات',
                  onTap: () => onNavigate(6),
                ),
                _QuickCard(
                  icon: Icons.assessment_outlined,
                  title: 'التقارير',
                  subtitle: 'ملخصات وتصدير PDF',
                  onTap: () => onNavigate(7),
                ),
                _QuickCard(
                  icon: Icons.history,
                  title: 'سجل المراجعة',
                  subtitle: 'تتبع العمليات الحساسة',
                  onTap: () => onNavigate(9),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

Future<void> _confirmLogout(
  BuildContext context,
  Future<void> Function() onSignOut,
) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('تسجيل الخروج'),
      content: const Text('هل تريد إنهاء جلسة الإدارة؟'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('خروج'),
        ),
      ],
    ),
  );
  if (ok == true && context.mounted) await onSignOut();
}

class _Metric extends StatelessWidget {
  const _Metric(
    this.title,
    this.value,
    this.icon, {
    this.accent = AppTheme.green,
    this.onTap,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color accent;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final iconColor = accent == AppTheme.gold
        ? const Color(0xFF9C7A3D)
        : accent;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(height: 9),
              Expanded(
                child: Align(
                  alignment: Alignment.topRight,
                  child: Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      height: 1.25,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 5),
              Text(
                value,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  color: AppTheme.ink,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickCard extends StatelessWidget {
  const _QuickCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final IconData icon;
  final String title, subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppTheme.paleGold,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(icon, color: AppTheme.green, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: AppTheme.ink,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 12),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Icon(
                        Icons.arrow_back_rounded,
                        color: AppTheme.green3,
                        size: 18,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
