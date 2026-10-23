import 'dart:typed_data'; import 'package:dartz/dartz.dart'; import '../../../core/cache/local_cache.dart'; import '../../../core/month_scope/accounting_month_scope.dart'; import '../../../core/errors/failure.dart'; import '../../../core/result.dart'; import '../domain/entities/traveler.dart'; import '../domain/entities/traveler_profile.dart';   import 'models/traveler_model.dart';   import 'models/traveler_profile_model.dart'; import '../domain/traveler_repository.dart'; import 'traveler_remote_data_source.dart';
class TravelerRepositoryImpl implements TravelerRepository { TravelerRepositoryImpl(this.remote, this.cache); final TravelerRemoteDataSourceImpl remote; final LocalCache cache;
 @override Future<Result<List<Traveler>>> list({String query=''}) async {
  final month = AccountingMonthScope.start;
  final cacheKey = 'travelers_list_${month.year}_${month.month.toString().padLeft(2, '0')}_${query.trim().toLowerCase()}';
  try {
    final rows = await remote.list(query);
    await cache.writeJson(cacheKey, rows, ttl: const Duration(hours: 12));
    return Right(rows.map(TravelerModel.fromMap).toList(growable: false));
  } catch (e) {
    final saved = cache.readJson(cacheKey);
    if (saved is List) {
      try {
        final rows = saved.whereType<Map>().map((row) => Map<String, dynamic>.from(row)).toList(growable: false);
        return Right(rows.map(TravelerModel.fromMap).toList(growable: false));
      } catch (_) {
        await cache.remove(cacheKey);
      }
    }
    return Left(ServerFailure('تعذر تحميل المسافرين ولا توجد نسخة محلية صالحة.', cause: e));
  }
}
 @override Future<Result<Traveler>> create({required String fullName,required String phone,required double agreementTotal,String? salesPerson,String? country}) async {if(fullName.trim().isEmpty)return const Left(ValidationFailure('اسم المسافر مطلوب.')); if(phone.trim().isEmpty)return const Left(ValidationFailure('رقم الهاتف مطلوب.')); if(agreementTotal<0)return const Left(ValidationFailure('إجمالي الاتفاق لا يمكن أن يكون سالبًا.')); try{final row=await remote.create({'full_name':fullName.trim(),'phone':phone.trim(),'agreement_total':agreementTotal,'sales_person':salesPerson,'destination_country':country});return Right(TravelerModel.fromMap(row));}catch(e){return Left(ServerFailure('تعذر إنشاء ملف المسافر.',cause:e));}}
 @override Future<Result<TravelerProfile>> profile(String id) async { try { final results=await Future.wait([remote.getTraveler(id),remote.payments(id),remote.documents(id)]); final traveler=results[0] as Map<String,dynamic>; final movements=results[1] as List<Map<String,dynamic>>; final documents=results[2] as List<Map<String,dynamic>>; await cache.writeJson('traveler_profile_$id', {'traveler':traveler,'movements':movements,'documents':documents}, ttl:const Duration(days:7)); return Right(TravelerProfileModel.fromData(traveler:traveler,movements:movements,documents:documents)); } catch(e) { final saved=cache.readJson('traveler_profile_$id'); if(saved is Map) { try { final data=Map<String,dynamic>.from(saved); final traveler=Map<String,dynamic>.from(data['traveler'] as Map); final movements=(data['movements'] as List).whereType<Map>().map((m)=>Map<String,dynamic>.from(m)).toList(); final documents=(data['documents'] as List).whereType<Map>().map((m)=>Map<String,dynamic>.from(m)).toList(); return Right(TravelerProfileModel.fromData(traveler:traveler,movements:movements,documents:documents,isCachedSnapshot:true)); } catch(_) {} } return Left(ServerFailure('تعذر تحميل ملف المسافر، ولا توجد نسخة محلية صالحة للعرض.',cause:e)); }}
 @override Future<Result<void>> addPayment({required String travelerId,required double amount,required String method,required String note}) async {if(travelerId.trim().isEmpty)return const Left(ValidationFailure('ملف المسافر غير صالح.'));if(!amount.isFinite||amount<=0)return const Left(ValidationFailure('قيمة الدفعة يجب أن تكون أكبر من صفر.'));if(!{'cash','instapay','bank_transfer','wallet','other'}.contains(method))return const Left(ValidationFailure('طريقة الدفع غير صحيحة.'));try{await remote.addPayment({'traveler_id':travelerId,'amount':amount,'payment_method':method,'note':note});await cache.remove('traveler_profile_$travelerId');return const Right(null);}catch(e){return Left(ServerFailure('تعذر تسجيل الدفعة. لم يتم تأكيد حفظها؛ حدّث الملف قبل إعادة المحاولة.',cause:e));}}
 @override Future<Result<void>> setStage({required String travelerId,required String stage,required bool value}) async { if(travelerId.trim().isEmpty||!{'submitted','inspected','visa','flight'}.contains(stage)) return const Left(ValidationFailure('بيانات المرحلة غير صحيحة.')); try { await remote.setStage(travelerId,stage,value); await cache.remove('traveler_profile_$travelerId'); return const Right(null); } catch(e) { return Left(ServerFailure('تعذر تعديل مرحلة المسافر. تحقق من الصلاحيات وحالة الاتصال.',cause:e)); } }
 @override Future<Result<void>> setTicketBooking({required String travelerId, required String? type, required String? note}) async {
   if (travelerId.trim().isEmpty || (type != null && !{'company','external'}.contains(type))) return const Left(ValidationFailure('اختيار حجز التذكرة غير صحيح.'));
   if (type == 'company' && (note == null || note.trim().isEmpty)) return const Left(ValidationFailure('اكتب ملاحظة الحجز عندما تكون التذكرة من خلال الشركة.'));
   try { await remote.setTicketBooking(travelerId, type, note); await cache.remove('traveler_profile_$travelerId'); return const Right(null); }
   catch(e) { return Left(ServerFailure('تعذر حفظ اختيار حجز التذكرة. يلزم تطبيق تحديث قاعدة البيانات المرفق.', cause:e)); }
 }
 @override Future<Result<void>> setAvatar({required String travelerId, required String fileName, required String mimeType, required Uint8List bytes}) async {
   if (travelerId.trim().isEmpty || bytes.isEmpty) return const Left(ValidationFailure('الصورة غير صالحة.'));
   try { await remote.setAvatar(travelerId, fileName, mimeType, bytes); await cache.remove('traveler_profile_$travelerId'); return const Right(null); }
   catch(e) { return Left(ServerFailure('تعذر حفظ صورة المسافر. تأكد من تطبيق تحديث قاعدة البيانات وصلاحيات Storage.', cause:e)); }
 }


 @override Future<Result<Traveler>> updateTraveler({required String travelerId,required String fullName,required String phone,required double agreementTotal,String? salesPerson,String? country}) async { if(travelerId.trim().isEmpty)return const Left(ValidationFailure('ملف المسافر غير صالح.')); if(fullName.trim().isEmpty)return const Left(ValidationFailure('اسم المسافر مطلوب.')); if(phone.trim().isEmpty)return const Left(ValidationFailure('رقم الهاتف مطلوب.')); if(!agreementTotal.isFinite||agreementTotal<0)return const Left(ValidationFailure('إجمالي الاتفاق غير صحيح.')); try { await remote.updateTraveler({'id':travelerId,'full_name':fullName.trim(),'phone':phone.trim(),'agreement_total':agreementTotal,'sales_person':salesPerson,'destination_country':country}); final row = await remote.getTraveler(travelerId); return Right(TravelerModel.fromMap(row)); } catch(e) { return Left(ServerFailure('تعذر تحديث بيانات المسافر.',cause:e)); } }

 @override Future<Result<void>> archiveTraveler({required String travelerId, required String reason}) async { if(travelerId.trim().isEmpty||reason.trim().isEmpty)return const Left(ValidationFailure('معرّف المسافر وسبب الإزالة مطلوبان.')); try { await remote.archiveTraveler(travelerId,reason); await cache.removePrefix('travelers_list_'); return const Right(null); } catch(e) { return Left(ServerFailure('تعذر أرشفة المسافر. إذا كانت له حركات مالية، سيتم الاحتفاظ بها في السجل.',cause:e)); } }
 @override Future<Result<bool>> deleteTraveler({required String travelerId, required String reason}) async { if(travelerId.trim().isEmpty||reason.trim().isEmpty)return const Left(ValidationFailure('معرّف المسافر وسبب الحذف مطلوبان.')); try { final storageCleaned=await remote.deleteTraveler(travelerId,reason); await cache.remove('traveler_profile_$travelerId'); await cache.removePrefix('travelers_list_'); return Right(storageCleaned); } catch(e) { return Left(ServerFailure('تعذر حذف المسافر. تحقق من الشهر المحاسبي وصلاحيات الأدمن؛ لم يتم تأكيد اكتمال الحذف.',cause:e)); } }

}
