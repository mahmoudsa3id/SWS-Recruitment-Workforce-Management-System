# إصلاحات تقرير flutter analyze

تم تطبيق الإصلاحات التالية بناءً على التقرير المرفق بتاريخ 16 أكتوبر 2026:

- تحديث استخدام `file_picker` إلى واجهته الساكنة الحديثة: `FilePicker.pickFile` و`FilePicker.saveFile` بدلًا من `FilePicker.platform`.
- تحديث اختيار الملفات إلى `pickFile()` لملف واحد، وقراءة البيانات عبر `PlatformFile.readAsBytes()` بدل الاعتماد على `withData` و`picked.files`.
- إضافة فحوصات للإلغاء والملفات الفارغة وأخطاء قراءة الملف، والتحقق من أن الشاشة ما زالت مركبة بعد الانتظار غير المتزامن.
- إعادة تسمية `MonthlyClosingCubit.close(...)` إلى `closeMonth(...)` لأن `close()` محجوزة لإغلاق الـ Cubit الموروث.
- معالجة النتيجة nullable من `ZipEncoder().encode()` قبل تحويلها إلى `Uint8List`.
- إزالة `const` غير الصحيحة من اختبار `MonthlyFinancialReport` الذي يحتوي على `DateTime` غير ثابت.
- تحديث `Table.fromTextArray` إلى `TableHelper.fromTextArray`، وتحديث `DropdownButtonFormField.value` إلى `initialValue`، واستبدال `withOpacity` بـ `withValues`، وحذف imports غير المستخدمة التي ظهرت في التقرير.

## التحقق

تم فحص 131 ملف Dart بفحص ساكن خفيف للـ imports النسبية وتوازن الأقواس، ولم تظهر أخطاء في هذا الفحص. هذا الفحص ليس محلل Dart ولا يثبت أن المشروع يبني بنجاح.

لم يتوفر Flutter SDK داخل بيئة إعداد الحزمة، لذلك لم أستطع تشغيل `flutter analyze` أو `flutter test` أو بناء Web/Windows هنا. يجب تشغيل الأوامر التالية على جهاز التطوير بعد فك الضغط:

```powershell
flutter pub get
flutter analyze
flutter test
flutter build web --release
flutter build windows --release
```

أي خطأ جديد يظهر من هذه الأوامر يجب إصلاحه قبل اعتماد النسخة للإنتاج.


## إضافات 2026-10-16
- إضافة تنزيل المستندات فعليًا عبر Storage API مع أيقونة تنزيل وحذف المستند بسبب موثق.
- أرشفة المسافر من القائمة مع حفظ السجل المالي وسجل المراجعة.
- ربط دفعات الرواتب والإيرادات العامة بطباعة إيصال بعد نجاح العملية، مع جلب رقم الإيصال من الحركة المسجلة.
- شريط الفترة المحاسبية يعيد إنشاء صفحات الوحدات عند تغيير الشهر، وتقرير لوحة التحكم أصبح يستخدم ملخص الشهر.
- خانة مسؤول المبيعات في إنشاء ملف المسافر.

لم يتم تشغيل Flutter analyzer/test/build في بيئة إعداد الحزمة؛ هذه الإضافات تحتاج تحققًا على جهاز Flutter وSupabase تجريبي.
