import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../../core/di/injection.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../domain/entities/audit_entry.dart';
import 'cubit/audit_cubit.dart';
import '../../../core/widgets/app_loading_skeleton.dart';

class AuditPage extends StatelessWidget {
  const AuditPage({super.key});
  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => sl<AuditCubit>()..load(),
    child: const _AuditView(),
  );
}

class _AuditView extends StatelessWidget {
  const _AuditView();
  @override
  Widget build(BuildContext context) => AppScaffold(
    title: 'سجل المراجعة',
    child: BlocBuilder<AuditCubit, AuditState>(
      builder: (context, state) {
        if (state is AuditInitial || state is AuditLoading) {
          return const AppLoadingSkeleton();
        }
        if (state is AuditFailure) {
          return Padding(
            padding: const EdgeInsets.all(20),
            child: ErrorPanel(
              message: state.message,
              onRetry: () => context.read<AuditCubit>().load(),
            ),
          );
        }
        final items = (state as AuditLoaded).items;
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const SectionTitle(
              'سجل العمليات الحساسة',
              subtitle:
                  'قراءة فقط — يحتفظ النظام بسبب التصحيح أو إعادة فتح الشهر.',
            ),
            const SizedBox(height: 12),
            if (items.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('لا توجد سجلات مراجعة.'),
                ),
              )
            else
              ...items.map(_entry),
          ],
        );
      },
    ),
  );
  Widget _entry(AuditEntry e) => Card(
    child: ExpansionTile(
      leading: const Icon(Icons.history),
      title: Text(
        e.action,
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
      subtitle: Text(
        '${e.entityType} • ${e.entityId ?? '—'}\n${DateFormat('yyyy-MM-dd HH:mm').format(e.createdAt)}',
      ),
      childrenPadding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
      children: [
        if ((e.reason ?? '').isNotEmpty)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Text('السبب: ${e.reason}'),
          ),
        if (e.beforeData != null)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: SelectableText('قبل: ${e.beforeData}'),
          ),
        if (e.afterData != null)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: SelectableText('بعد: ${e.afterData}'),
          ),
      ],
    ),
  );
}
