import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/di/injection.dart';
import '../../../core/widgets/app_scaffold.dart';
import 'cubit/settings_cubit.dart';
import '../../../core/widgets/app_loading_skeleton.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});
  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => sl<SettingsCubit>()..load(),
    child: const _SettingsView(),
  );
}

class _SettingsView extends StatelessWidget {
  const _SettingsView();
  @override
  Widget build(BuildContext context) => AppScaffold(
    title: 'إعدادات النظام',
    child: BlocBuilder<SettingsCubit, SettingsState>(
      builder: (context, state) {
        if (state is SettingsInitial || state is SettingsLoading) {
          return const AppLoadingSkeleton();
        }
        if (state is SettingsFailure) {
          return Padding(
            padding: const EdgeInsets.all(20),
            child: ErrorPanel(
              message: state.message,
              onRetry: () => context.read<SettingsCubit>().load(),
            ),
          );
        }
        final s = (state as SettingsLoaded).settings;
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const SectionTitle(
              'إعدادات التطبيق والأمان',
              subtitle:
                  'إعدادات الواجهة الأساسية والتحكم في الكاش على الجهاز الحالي.',
            ),
            const SizedBox(height: 16),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.business_outlined),
                    title: const Text('اسم النظام'),
                    subtitle: Text(s.appName),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.language_outlined),
                    title: const Text('اللغة والاتجاه'),
                    subtitle: Text(s.language),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.admin_panel_settings_outlined),
                    title: const Text('حساب الجلسة الحالية'),
                    subtitle: Text(s.signedInEmail),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.storage_outlined),
                    title: const Text('الكاش المحلي'),
                    subtitle: Text('النطاق: ${s.cacheNamespace}'),
                    trailing: TextButton(
                      onPressed: () => _clear(context),
                      child: const Text('مسح الكاش'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Card(
              child: Padding(
                padding: EdgeInsets.all(18),
                child: Text(
                  'ملاحظات الأمان: لا تضع service_role key في التطبيق. صلاحيات البيانات تفرضها سياسات Supabase RLS ودوال RPC. عمليات المال محظورة عند انقطاع الاتصال، والكاش لا يستخدم كدليل صلاحية أو مصدر مالي موثوق.',
                ),
              ),
            ),
          ],
        );
      },
    ),
  );
}

Future<void> _clear(BuildContext context) async {
  final accepted = await showDialog<bool>(
    context: context,
    builder: (d) => AlertDialog(
      title: const Text('مسح الكاش المحلي'),
      content: const Text(
        'سيتم حذف البيانات المؤقتة المحفوظة على هذا الجهاز. لن يتم حذف بيانات Supabase.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(d, false),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(d, true),
          child: const Text('مسح الكاش'),
        ),
      ],
    ),
  );
  if (accepted != true || !context.mounted) return;
  final error = await context.read<SettingsCubit>().clearCache();
  if (!context.mounted) return;
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(error ?? 'تم مسح الكاش المحلي.')));
}
