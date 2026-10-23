import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../../core/di/injection.dart';
import '../../../core/month_scope/accounting_month_scope.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../domain/entities/monthly_closing.dart';
import 'cubit/monthly_closing_cubit.dart';
import '../../../core/widgets/app_loading_skeleton.dart';

class MonthlyClosingPage extends StatelessWidget { const MonthlyClosingPage({super.key}); @override Widget build(BuildContext context)=>BlocProvider(create:(_)=>sl<MonthlyClosingCubit>()..load(),child:const _ClosingView()); }
class _ClosingView extends StatelessWidget {
 const _ClosingView();
 Future<void> _close(BuildContext context) async {final now=AccountingMonthScope.start;final note=TextEditingController();final accepted=await showDialog<bool>(context:context,builder:(d)=>AlertDialog(title:const Text('إقفال الشهر الحالي'),content:Text('سيتم احتساب رصيد الإقفال من الحركات المالية المسجلة لشهر ${DateFormat('MMMM yyyy','ar').format(now)}. هذا الإجراء يتطلب مراجعة الحسابات قبل التنفيذ.'),actions:[TextButton(onPressed:()=>Navigator.pop(d,false),child:const Text('رجوع')),FilledButton(onPressed:()=>Navigator.pop(d,true),child:const Text('تأكيد الإقفال'))]));if(accepted!=true||!context.mounted)return;final error=await context.read<MonthlyClosingCubit>().closeMonth(DateTime(now.year,now.month,1),note:note.text);if(!context.mounted)return;ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(error??'تم إقفال الشهر.')));if(error==null)await context.read<MonthlyClosingCubit>().load();}
 Future<void> _reopen(BuildContext context,MonthlyClosing item) async {final reason=TextEditingController();final accepted=await showDialog<bool>(context:context,builder:(d)=>AlertDialog(title:const Text('إعادة فتح الشهر'),content:TextField(controller:reason,minLines:2,maxLines:3,decoration:const InputDecoration(labelText:'سبب إعادة الفتح *')),actions:[TextButton(onPressed:()=>Navigator.pop(d,false),child:const Text('إلغاء')),FilledButton(onPressed:()=>Navigator.pop(d,true),child:const Text('إعادة الفتح'))]));if(accepted!=true||!context.mounted)return;final error=await context.read<MonthlyClosingCubit>().reopen(item.monthStart,reason.text);if(!context.mounted)return;ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(error??'تمت إعادة فتح الشهر.')));if(error==null)await context.read<MonthlyClosingCubit>().load();}
 @override
 Widget build(BuildContext context) {
   return AppScaffold(
     title: 'الإقفال الشهري',
     actions: [
       Padding(
         padding: const EdgeInsetsDirectional.only(end: 12),
         child: FilledButton.icon(
           onPressed: () => _close(context),
           icon: const Icon(Icons.lock_outline),
           label: const Text('إقفال الشهر الحالي'),
         ),
       ),
     ],
     child: BlocBuilder<MonthlyClosingCubit, MonthlyClosingState>(
       builder: (context, state) {
         if (state is MonthlyClosingInitial || state is MonthlyClosingLoading) {
           return const AppLoadingSkeleton();
         }
         if (state is MonthlyClosingFailure) {
           return Padding(
             padding: const EdgeInsets.all(20),
             child: ErrorPanel(
               message: state.message,
               onRetry: () => context.read<MonthlyClosingCubit>().load(),
             ),
           );
         }
         final items = (state as MonthlyClosingLoaded).items;
         return ListView(
           padding: const EdgeInsets.all(20),
           children: [
             const SectionTitle('أرشيف الإقفالات', subtitle: 'إعادة فتح شهر مقفول تتطلب سببًا مسجلًا في سجل المراجعة.'),
             const SizedBox(height: 14),
             if (items.isEmpty)
               const Card(child: Padding(padding: EdgeInsets.all(24), child: Text('لا توجد إقفالات سابقة.')))
             else
               ...items.map((item) => _closingTile(context, item)),
           ],
         );
       },
     ),
   );
 }
 Widget _closingTile(BuildContext context, MonthlyClosing item) {
   return Card(
     child: ListTile(
       leading: Icon(item.isClosed ? Icons.lock_outline : Icons.lock_open, color: item.isClosed ? Colors.red : Colors.green),
       title: Text(DateFormat('MMMM yyyy', 'ar').format(item.monthStart), style: const TextStyle(fontWeight: FontWeight.w800)),
       subtitle: Text('رصيد بداية ${item.openingBalance.toStringAsFixed(2)} • رصيد نهاية ${item.closingBalance.toStringAsFixed(2)} ج.م\n${item.isClosed ? 'مقفل' : 'مفتوح'}${item.reopenReason == null ? '' : ' • سبب الفتح: ${item.reopenReason}'}'),
       isThreeLine: true,
       trailing: item.isClosed
           ? TextButton(onPressed: () => _reopen(context, item), child: const Text('إعادة فتح'))
           : const Chip(label: Text('مفتوح')),
     ),
   );
 }
}
