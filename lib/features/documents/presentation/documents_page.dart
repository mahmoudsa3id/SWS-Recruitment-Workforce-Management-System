import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/di/injection.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/app_loading_skeleton.dart';
import '../../travelers/domain/usecases/list_travelers.dart';
import '../domain/entities/traveler_document.dart';
import 'cubit/documents_cubit.dart';

class DocumentsPage extends StatelessWidget { const DocumentsPage({super.key}); @override Widget build(BuildContext context)=>BlocProvider(create:(_)=>sl<DocumentsCubit>(),child:const _DocumentsView()); }
class _DocumentsView extends StatefulWidget { const _DocumentsView(); @override State<_DocumentsView> createState()=>_DocumentsViewState(); }
class _DocumentsViewState extends State<_DocumentsView> {
 List<Map<String,dynamic>> travelers=[]; String? selectedTraveler; String type='الصورة والباسبور'; bool loadingTravelers=true,uploading=false; String? travelerError;
 static const types=['الصورة والباسبور','التأشيرة','إثبات التاريخ','تذكرة الطيران','مستندات أخرى'];
 @override void initState(){super.initState();_loadTravelers();}
 Future<void> _loadTravelers() async {try{final r=await sl<ListTravelers>()();r.fold((f){if(mounted)setState(()=>travelerError=f.message);},(items){if(!mounted)return;travelers=items.map((t)=>{'id':t.id,'full_name':t.fullName,'file_no':t.fileNo}).toList();selectedTraveler=travelers.isEmpty?null:'${travelers.first['id']}';final selectedId = selectedTraveler; if(selectedId != null)context.read<DocumentsCubit>().load(selectedId);});}finally{if(mounted)setState(()=>loadingTravelers=false);}}
 String _mime(String? extension)=>switch((extension??'').toLowerCase()){ 'pdf'=>'application/pdf','jpg'||'jpeg'=>'image/jpeg','png'=>'image/png','webp'=>'image/webp',_=>'application/octet-stream'};
 Future<void> _upload() async {
   final traveler = selectedTraveler;
   if (traveler == null) {
     ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('أضف مسافرًا أولًا.')));
     return;
   }
   final file = await FilePicker.pickFile(
     type: FileType.custom,
     allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png', 'webp'],
   );
   if (file == null || !mounted) return;
   late final List<int> bytes;
   try {
     bytes = await file.readAsBytes();
   } catch (_) {
     if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذر قراءة الملف المحدد.')));
     return;
   }
   if (!mounted) return;
   if (bytes.isEmpty) {
     ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الملف المحدد فارغ.')));
     return;
   }
   setState(() => uploading = true);
   final error = await context.read<DocumentsCubit>().upload(
     travelerId: traveler,
     type: type,
     fileName: file.name,
     mimeType: _mime(file.extension),
     bytes: Uint8List.fromList(bytes),
   );
   if (!mounted) return;
   setState(() => uploading = false);
   ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error ?? 'تم رفع المستند بنجاح.')));
   if (error == null) await context.read<DocumentsCubit>().load(traveler);
 }
 Future<void> _download(TravelerDocument doc) async {
   try {
     final bytes = await context.read<DocumentsCubit>().download(doc.storagePath);
     if (!mounted) return;
     if (bytes == null || bytes.isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذر قراءة بيانات المستند من التخزين.'))); return; }
     final extension = doc.fileName.contains('.') ? doc.fileName.split('.').last : 'bin';
     final saved = await FilePicker.saveFile(dialogTitle: 'تنزيل المستند', fileName: doc.fileName, type: FileType.custom, allowedExtensions: [extension], bytes: bytes);
     if (!mounted || saved == null) return;
     ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تجهيز تنزيل المستند.')));
   } catch (_) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذر تنزيل المستند. تحقق من الصلاحيات والاتصال.'))); }
 }
 Future<void> _delete(TravelerDocument doc) async {
   final reason = TextEditingController();
   final accepted = await showDialog<bool>(context: context, builder: (d) => AlertDialog(title: const Text('حذف المستند'), content: Column(mainAxisSize: MainAxisSize.min, children: [Text('سيتم حذف سجل المستند ${doc.fileName} من ملف المسافر.'), const SizedBox(height: 12), TextField(controller: reason, decoration: const InputDecoration(labelText: 'سبب الحذف *'), minLines: 2, maxLines: 3)]), actions: [TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('إلغاء')), FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('حذف'))]));
   if (accepted != true || !mounted) return;
   if (reason.text.trim().isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('اكتب سبب الحذف أولًا.'))); return; }
   final error = await context.read<DocumentsCubit>().delete(documentId: doc.id, storagePath: doc.storagePath, reason: reason.text.trim());
   if (!mounted) return;
   ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error ?? 'تم حذف المستند.')));
   final id = selectedTraveler; if (error == null && id != null) await context.read<DocumentsCubit>().load(id);
 }
 Future<void> _open(TravelerDocument doc) async {final result=await context.read<DocumentsCubit>().link(doc.storagePath);if(!mounted)return;if(result==null){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('تعذر إنشاء رابط المستند.')));return;}final uri=Uri.tryParse(result);if(uri==null||!await launchUrl(uri,mode:LaunchMode.externalApplication)){if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('تعذر فتح رابط المستند.')));}}
 @override Widget build(BuildContext context)=>AppScaffold(title:'مستندات المسافرين',actions:[Padding(padding:const EdgeInsetsDirectional.only(end:12),child:FilledButton.icon(onPressed:uploading?null:_upload,icon:uploading?const SizedBox(width:16,height:16,child:CircularProgressIndicator(strokeWidth:2)):const Icon(Icons.upload_file),label:Text(uploading?'جارٍ الرفع…':'رفع مستند')))],child:ListView(padding:const EdgeInsets.all(20),children:[const SectionTitle('أرشيف ملفات المستندات',subtitle:'كل مستند يظهر كملف مستقل مع تنزيل وفتح وحذف، دون شجرة مجلدات.'),const SizedBox(height:16),if(loadingTravelers)const AppLoadingRows(rows: 1)else if(travelerError!=null)ErrorPanel(message:travelerError ?? 'تعذر تحميل المسافرين.',onRetry:_loadTravelers),DropdownButtonFormField<String>(initialValue:selectedTraveler,decoration:const InputDecoration(labelText:'المسافر'),items:travelers.map((t)=>DropdownMenuItem(value:'${t['id']}',child:Text('${t['full_name']} • ${t['file_no']??'بدون رقم ملف'}'))).toList(),onChanged:(v){setState(()=>selectedTraveler=v);if(v!=null)context.read<DocumentsCubit>().load(v);}),const SizedBox(height:10),DropdownButtonFormField<String>(initialValue:type,decoration:const InputDecoration(labelText:'نوع المستند'),items:types.map((v)=>DropdownMenuItem(value:v,child:Text(v))).toList(),onChanged:(v)=>setState(()=>type=v??types.first)),const SizedBox(height:16),BlocBuilder<DocumentsCubit,DocumentsState>(builder:(context,state){if(selectedTraveler==null)return const Card(child:Padding(padding:EdgeInsets.all(24),child:Text('أضف مسافرًا لبدء حفظ المستندات.')));if(state is DocumentsLoading||state is DocumentsInitial)return const AppLoadingRows(rows: 3);if(state is DocumentsFailure)return ErrorPanel(message:state.message,onRetry:(){final selectedId=selectedTraveler;if(selectedId!=null)context.read<DocumentsCubit>().load(selectedId);});final docs=(state as DocumentsLoaded).items;if(docs.isEmpty)return const Card(child:Padding(padding:EdgeInsets.all(24),child:Text('لا توجد مستندات لهذا المسافر.')));return Column(children:docs.map(_tile).toList());})]));
 Widget _tile(TravelerDocument d)=>Card(child:ListTile(leading:const CircleAvatar(child:Icon(Icons.description_outlined)),title:Text(d.fileName,style:const TextStyle(fontWeight:FontWeight.w800)),subtitle:Text('${d.type} • ${((d.fileSize??0)/1024).toStringAsFixed(1)} KB'),trailing:Wrap(spacing:0, children:[IconButton(tooltip:'تنزيل المستند',onPressed:()=>_download(d),icon:const Icon(Icons.download_outlined)),IconButton(tooltip:'فتح رابط آمن',onPressed:()=>_open(d),icon:const Icon(Icons.open_in_new)),IconButton(tooltip:'حذف المستند',onPressed:()=>_delete(d),icon:const Icon(Icons.delete_outline,color:Colors.red))])));
}
