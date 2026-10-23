# ابدأ من هنا — SWS

هذه حزمة مصدر لإعادة بناء نظام SWS من الصفر، وليست ملف EXE أو Web build مجازًا للإنتاج.

## 1) ربط Supabase

- استخدم مشروع Supabase جديدًا وفارغًا، ولا تستخدم قاعدة بيانات SWS القديمة مباشرة.
- من SQL Editor، شغّل migrations بالترتيب المذكور في `README_AR.md` (001 ثم 002 ثم 003 ثم 004).
- أنشئ مستخدم الإدارة من Authentication → Users.
- عدّل البريد داخل `supabase/bootstrap_admin.sql`، ثم شغّله مرة واحدة.
- لا تضع service_role أو Secret Key في التطبيق.

## 2) تشغيل Web / Chrome

```powershell
flutter config --enable-web
flutter pub get
flutter run -d chrome --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co --dart-define=SUPABASE_PUBLISHABLE_KEY=YOUR_PUBLISHABLE_KEY
```

## 3) تشغيل Windows Desktop

ثبت Visual Studio مع `Desktop development with C++` ثم:

```powershell
flutter config --enable-windows-desktop
flutter pub get
flutter run -d windows --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co --dart-define=SUPABASE_PUBLISHABLE_KEY=YOUR_PUBLISHABLE_KEY
```

## 4) قبل إدخال بيانات حقيقية

```powershell
flutter analyze
flutter test
flutter build web --release --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co --dart-define=SUPABASE_PUBLISHABLE_KEY=YOUR_PUBLISHABLE_KEY
flutter build windows --release --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co --dart-define=SUPABASE_PUBLISHABLE_KEY=YOUR_PUBLISHABLE_KEY
```

اختبر حسابات التحصيل والعكس، الدفعات الجزئية للمرتبات، إقفال الشهر وإعادة فتحه، وسياسات الصلاحيات على قاعدة اختبار. لا تشغّل أي SQL reset من مشروع قديم فوق بيانات موجودة.
