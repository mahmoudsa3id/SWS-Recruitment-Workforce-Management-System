# معمارية SWS — قواعد التنفيذ

## الحدود المعمارية

- `domain/entities`: كائنات المجال وقواعد العمل، لا تستورد Flutter أو Supabase أو أي package خاص بالتخزين.
- `domain/repositories`: عقود الوصول للبيانات.
- `domain/usecases`: عملية واحدة لكل حالة استخدام، مع التحقق من المدخلات قبل الوصول للمستودع.
- `data/models`: تحويل JSON إلى نماذج المجال والعكس.
- `data/datasources`: الاتصال الفعلي بمصدر البيانات، ولا تستدعيه الواجهة مباشرة.
- `data/repositories`: تنفيذ عقود المجال وتحويل أخطاء المصدر إلى Failure مفهومة.
- `presentation/cubit`: حالات العرض والتنسيق فقط؛ لا يحتوي على استعلامات SQL/Supabase.

## مسار تحميل ملف المسافر

`Page → Cubit → LoadTravelerProfile → TravelerProfileRepository → SupabaseTravelerProfileRemoteDataSource → Supabase`

## قواعد لا يجوز تجاوزها

1. الواجهة لا تستدعي `SupabaseClient` مباشرة في أي ميزة يجري نقلها إلى المعمارية الجديدة.
2. الـ Entity لا يحمل `Map<String, dynamic>` كبديل عن حقول المجال.
3. العمليات المالية تحتاج اتصالًا مؤكدًا بالخادم؛ لا تحفظ كحركة مالية نهائية في كاش محلي.
4. التحقق من الصلاحيات والإقفال المالي يجب أن يفرضه الخادم وسياسات RLS/دوال SQL، وليس الواجهة فقط.
5. أخطاء الشبكة والصلاحيات والتحقق تُحوّل إلى Failure، ولا تعرض Stack Trace للمستخدم.
6. لا تُعتبر نسخة Production معتمدة قبل تشغيل `flutter analyze`, `flutter test`، بناء المنصات المستهدفة واختبار RLS والتدفقات المالية على مشروع Supabase منفصل.

## حالة النقل الحالية

أُضيفت طبقات Entity/Model/Remote Data Source/Repository Contract/Use Case/Cubit لملف المسافر، وأضيفت أدوات حركة واجهة قابلة لإعادة الاستخدام. توجد أجزاء قديمة في `main.dart` تستخدم `part` ومنطقًا مباشرًا مع Supabase، وهي ما زالت تحتاج نقلًا ميزةً بميزة قبل اعتبار فصل المعمارية مكتملًا. لا تُخفَ هذه الحقيقة ولا يُدّعى أن كل الوحدات أصبحت Clean Architecture بعد.
