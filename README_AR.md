# SWS Admin — Clean Rebuild

**المشروع:** نظام الإدارة الداخلية لشركة شمس الإبداع. **المنصات المستهدفة:** Flutter Web وWindows Desktop. **اللغة:** العربية RTL.

## المعمارية

كل ميزة رئيسية لها طبقات منفصلة:

- `domain/entities`: قواعد البيانات والمجال دون اعتماد على Flutter أو Supabase.
- `domain/repositories`: العقود.
- `domain/usecases`: العمليات التي تنفذ قواعد المجال.
- `data/models`: التحويل والتحقق من قيم قاعدة البيانات.
- `data/datasources`: الاتصال بقاعدة البيانات وStorage.
- `data/repositories`: تنفيذ العقود وتحويل الأخطاء إلى `Failure`.
- `presentation/cubit`: إدارة حالة الواجهة دون استعلامات Supabase مباشرة.

الوحدات: المصادقة، لوحة التحكم، المسافرون والملفات الشخصية، المستندات، الحركات المالية، المصروفات، المرتبات، الإقفال الشهري، التقارير، سجل المراجعة والإعدادات. حقن الاعتماديات في `core/di` باستخدام GetIt، والنتائج المتوقعة تستخدم `Either<Failure, T>`.

## التشغيل محليًا

تحتاج Flutter SDK متوافقًا مع `environment.sdk` في `pubspec.yaml` وVisual Studio مع Desktop development with C++ لبناء Windows وChrome لتشغيل الويب.

### Web / Chrome

```powershell
flutter config --enable-web
flutter pub get
flutter run -d chrome --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co --dart-define=SUPABASE_PUBLISHABLE_KEY=YOUR_PUBLISHABLE_KEY
```

### Windows Desktop

```powershell
flutter config --enable-windows-desktop
flutter pub get
flutter run -d windows --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co --dart-define=SUPABASE_PUBLISHABLE_KEY=YOUR_PUBLISHABLE_KEY
```

لا تضع `service_role` أو أي Secret key في Flutter. استخدم Publishable/anon key فقط؛ الحماية الحقيقية في سياسات RLS ودوال RPC.

## إعداد قاعدة البيانات — مشروع تجريبي جديد فقط

**المخطط المقصود من الصفر. لا تشغّل هذه الـ migrations فوق قاعدة SWS القديمة أو بيانات إنتاج موجودة.** خذ نسخة احتياطية واختبر أولًا في مشروع Supabase جديد وفارغ.

شغّل الملفات بالترتيب التالي من Supabase SQL Editor:

1. `supabase/migrations/202610160001_sws_clean_schema.sql`
2. `supabase/migrations/202610160002_sws_operations.sql`
3. `supabase/migrations/202610160003_sws_security_and_idempotency.sql`
4. `supabase/migrations/202610160004_sws_operations_completion.sql`

بعدها:

1. أنشئ مستخدمًا من **Authentication → Users** مع Email/Password.
2. استبدل `YOUR_ADMIN_EMAIL@example.com` في `supabase/bootstrap_admin.sql` ببريد المستخدم، ثم نفّذ الملف مرة واحدة.
3. تأكد أن الملف الشخصي يحمل `role='admin'` و`is_active=true`.
4. تأكد من وجود private bucket باسم `sws-private-documents`؛ migration 002 تنشئه عبر Storage metadata API.

لا تحذف بيانات الملفات مباشرة من `storage.objects`. استخدم Supabase Storage API.

## ضمانات المحاسبة المطبقة في قاعدة البيانات

- كل الحركات المالية تسجل من خلال RPC مع تحقق إداري وسجل مراجعة.
- الدفعات تستخدم idempotency key على مستوى كل طلب، والعكس ينشئ حركة مقابلة ولا يحذف الحركة الأصلية.
- إيراد المسافر يُسجل كحركة واحدة؛ لا يُعاد إدخاله كإيراد عام.
- المدفوع فقط يُسجل كتدفق نقدي للمرتبات؛ المتبقي محسوب كالتزام.
- قفل الشهر والتحقق من الحركات يتمان في قاعدة البيانات بتوقيت المحاسبة `Africa/Cairo`.
- التقارير الإجمالية تحسب على الخادم لتجنب قص النتائج عند حد الصفوف.
- لا تنفذ عمليات مالية دون اتصال، ولا تستخدم الكاش لتفويض المستخدم.

## الاختبارات والتحقق قبل الإنتاج

نفّذ من جذر المشروع:

```powershell
flutter pub get
flutter analyze
flutter test
flutter build web --release --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co --dart-define=SUPABASE_PUBLISHABLE_KEY=YOUR_PUBLISHABLE_KEY
flutter build windows --release --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co --dart-define=SUPABASE_PUBLISHABLE_KEY=YOUR_PUBLISHABLE_KEY
```

**لم يتم تشغيل هذه الأوامر في بيئة إعداد الأرشيف لأن Flutter/Dart SDK غير متوفر فيها.** لا تعتبر الحزمة مجازة للإنتاج قبل نجاح التحليل والاختبارات والبناء واختبارات التكامل على قاعدة اختبار. راجع `KNOWN_LIMITATIONS_AR.md`.

## إصلاحات تقرير التحليل

راجع `ANALYZER_FIXES_AR.md` للتغييرات التي تمت لمعالجة الأخطاء والتحذيرات الواردة في تقرير `flutter analyze`.


## تحديث سير العمل الشهري والطباعة
راجع `WORKFLOW_UPDATES_AR.md` للتغييرات الأخيرة في تحديد الشهر، المكافآت والأوفر تايم، تنزيل المستندات وحذفها، وطباعة إيصالات الدفع.


## إضافات واجهة التشغيل الحالية
- شريط الفترة المحاسبية مشترك؛ تغيير الشهر يعيد إنشاء صفحات الوحدات ويغير نطاق الاستعلامات الشهرية.
- المسافرون الجدد لهم خانة «تبع مين؟ مسؤول المبيعات»، والإزالة تتم كأرشفة موثقة بدل حذف السجل المالي.
- مستندات المسافر تظهر كقائمة ملفات مستقلة مع تنزيل وفتح وحذف مسجل السبب.
- تسجيل دفعة للمسافر يفتح إيصالها للطباعة تلقائيًا، وكذلك تسجيل الإيراد العام وصرف الراتب.
- نموذج الراتب يشمل الأساسي والعمولة والمكافأة وساعات الأوفر تايم وسعر الساعة والخصومات.
- شريط التنقل السفلي يعرض تسمية العنصر المحدد فقط لتقليل تجاوز العرض على الشاشات الضيقة.

## ترحيل قاعدة البيانات
تأكد من تطبيق `supabase/migrations/202610160001_sws_clean_schema.sql` إلى `202610160005_sws_monthly_workflow_crud_live.sql` بالترتيب. Migration رقم 005 ضروري لحقول المكافأة والأوفر تايم، والأرشفة، وقائمة المسافرين الشهرية، ودوال الإقفال والتعديل والحذف. جرّب على قاعدة اختبار قبل الإنتاج.


## تحديث سير عمل المسافر والملف الشخصي (2026-10-23)

لإضافة صورة الملف الشخصي وخيارات حجز التذكرة إلى قاعدة SWS الحالية، استخدم فقط الملف الإضافي:

`supabase/migrations/202610230001_sws_traveler_workflow_profile.sql`

هذا التحديث **إضافي فقط**: يضيف أعمدة اختيارية ودوال RPC جديدة ويحدّث دالة عرض المسافرين؛ لا يحذف المسافرين أو الدفعات ولا يعيد إنشاء الجداول. مع ذلك، خذ نسخة احتياطية وراجع صلاحيات Storage/RPC قبل تطبيقه على الإنتاج. لا تشغّل `INSTALL_ALL_MIGRATIONS.sql` على قاعدة الإنتاج الموجودة.

بعد تطبيق التحديث شغّل `flutter pub get` ثم `flutter analyze` واختبر أولًا على نسخة تجريبية. صورة المسافر اختيارية، وتظهر صورة افتراضية عند عدم وجود صورة. القائمة أصبحت تعرض المسافرين عبر كل الشهور لتسمح بعرض المسددين بالكامل والمتأخرين في السداد، بينما تبقى التقارير المالية محددة بالفترة المحاسبية المختارة.


## صلاحيات HR وطلبات العمليات المالية (2026-10-23)

- طبّق `supabase/migrations/202610230002_sws_hr_role.sql` أولًا إذا لم يكن قد طُبّق بالفعل.
- ثم طبّق `supabase/migrations/202610230003_sws_hr_traveler_finance_requests.sql` على قاعدة البيانات الحالية. هذا الترحيل إضافي ولا يحذف المسافرين أو الدفعات أو المستندات.
- حساب HR يرى إجمالي الاتفاق، المدفوع، المتبقي، وسجل دفعات المسافر وملفاته؛ ويمكنه تحديث مراحل قدم/كشف/تأشيرة/طيران وخيار حجز التذكرة.
- زر HR المالي ينشئ طلب دفعة معلّقًا؛ لا يتغير رصيد المسافر حتى يوافق الأدمن من «طلبات العمليات المالية». الرفض لا ينشئ حركة مالية.
- لا تمنح هذه الصلاحيات HR حق فتح شاشة الحركات المالية العامة أو المصروفات أو الرواتب أو الإقفال والتقارير.
- خذ نسخة احتياطية وجرّب الترحيل على بيئة اختبار أولًا، ولا تشغّل `INSTALL_ALL_MIGRATIONS.sql` على قاعدة الإنتاج الحالية.
