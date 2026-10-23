import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/cache/local_cache.dart';
import 'core/result.dart';
import 'core/di/injection.dart';
import 'core/widgets/app_loading_skeleton.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/domain/usecases/check_admin_access.dart';
import 'features/auth/presentation/login_page.dart';
import 'features/dashboard/presentation/dashboard_page.dart';

const _url = String.fromEnvironment(
  'SUPABASE_URL',
  defaultValue: 'https://aidukiieeulfzofzezow.supabase.co',
);
const _key = String.fromEnvironment(
  'SUPABASE_PUBLISHABLE_KEY',
  defaultValue: 'sb_publishable_ekeUegTgbLD9sw28sB-HXg_HYvM2Qm0',
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ar');
  String? startupError;
  var configured = false;
  if (_url.startsWith('https://') && _key.isNotEmpty) {
    try {
      await Supabase.initialize(url: _url, publishableKey: _key);
      await configureDependencies(Supabase.instance.client);
      configured = true;
    } catch (_) {
      startupError =
          'تعذر تهيئة اتصال Supabase. راجع عنوان المشروع والمفتاح واتصال الإنترنت.';
    }
  }
  runApp(SWSApp(configured: configured, startupError: startupError));
}

class SWSApp extends StatelessWidget {
  const SWSApp({super.key, required this.configured, this.startupError});
  final bool configured;
  final String? startupError;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'SWS | شمس الإبداع',
    debugShowCheckedModeBanner: false,
    theme: AppTheme.light,
    builder: (context, child) => Directionality(
      textDirection: TextDirection.rtl,
      child: child ?? const SizedBox.shrink(),
    ),
    home: startupError != null
        ? _StartupFailure(message: startupError ?? 'تعذر بدء التطبيق.')
        : !configured
        ? const _SetupPage()
        : const _AuthGate(),
  );
}

class _SetupPage extends StatelessWidget {
  const _SetupPage();
  @override
  Widget build(BuildContext context) => const Scaffold(
    body: Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.settings_suggest_outlined, size: 48),
                SizedBox(height: 12),
                Text(
                  'إعداد اتصال Supabase',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text(
                  'شغّل التطبيق باستخدام SUPABASE_URL و SUPABASE_PUBLISHABLE_KEY عبر dart-define. استخدم المفتاح Publishable/anon فقط.',
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _StartupFailure extends StatelessWidget {
  const _StartupFailure({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.cloud_off_outlined,
                    size: 44,
                    color: Colors.red,
                  ),
                  const SizedBox(height: 12),
                  Text(message, textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  const Text(
                    'أعد تشغيل التطبيق بعد تصحيح الإعدادات.',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _AuthGate extends StatefulWidget {
  const _AuthGate();
  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> {
  @override
  Widget build(BuildContext context) {
    final client = Supabase.instance.client;
    return StreamBuilder<AuthState>(
      stream: client.auth.onAuthStateChange,
      initialData: AuthState(
        AuthChangeEvent.initialSession,
        client.auth.currentSession,
      ),
      builder: (context, snapshot) {
        final user = client.auth.currentUser;
        if (user == null)
          return LoginPage(
            onSignedIn: () {
              if (mounted) setState(() {});
            },
          );
        return _AdminGate(
          key: ValueKey(user.id),
          userId: user.id,
          onSignOut: () async {
            try {
              await sl<LocalCache>().clearAll();
            } catch (_) {}
            await client.auth.signOut();
            if (mounted) setState(() {});
          },
        );
      },
    );
  }
}

class _AdminGate extends StatefulWidget {
  const _AdminGate({super.key, required this.userId, required this.onSignOut});
  final String userId;
  final Future<void> Function() onSignOut;
  @override
  State<_AdminGate> createState() => _AdminGateState();
}

class _AdminGateState extends State<_AdminGate> {
  late Future<Result<bool>> _profile;
  late Future<bool> _isHr;

  @override
  void initState() {
    super.initState();
    _profile = _load();
    _isHr = _loadIsHr();
  }

  Future<bool> _loadIsHr() async {
    final row = await sl<SupabaseClient>().from('profiles').select('role,is_active').eq('user_id', widget.userId).maybeSingle();
    return row != null && row['role'] == 'hr' && row['is_active'] == true;
  }

  Future<Result<bool>> _load() => sl<CheckAdminAccess>()(widget.userId);

  @override
  Widget build(BuildContext context) => FutureBuilder<Result<bool>>(
    future: _profile,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Scaffold(body: AppLoadingSkeleton());
      }
      final result = snapshot.data;
      if (snapshot.hasError || result == null) {
        return Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.cloud_off_outlined, size: 48),
                  const SizedBox(height: 12),
                  const Text(
                    'تعذر التحقق من صلاحيات الحساب. تحقق من اتصال Supabase ثم أعد المحاولة.',
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () => setState(() { _profile = _load(); _isHr = _loadIsHr(); }),
                    child: const Text('إعادة المحاولة'),
                  ),
                  TextButton(
                    onPressed: widget.onSignOut,
                    child: const Text('تسجيل الخروج'),
                  ),
                ],
              ),
            ),
          ),
        );
      }
      return result.fold(
        (failure) => Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.cloud_off_outlined, size: 48),
                  const SizedBox(height: 12),
                  Text(failure.message, textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () => setState(() { _profile = _load(); _isHr = _loadIsHr(); }),
                    child: const Text('إعادة المحاولة'),
                  ),
                  TextButton(
                    onPressed: widget.onSignOut,
                    child: const Text('تسجيل الخروج'),
                  ),
                ],
              ),
            ),
          ),
        ),
        (allowed) => allowed
            ? FutureBuilder<bool>(future: _isHr, builder: (context, roleSnapshot) {
                if (roleSnapshot.connectionState != ConnectionState.done) return const Scaffold(body: AppLoadingSkeleton());
                if (roleSnapshot.hasError) return Scaffold(body: Center(child: FilledButton(onPressed: () => setState(() => _isHr = _loadIsHr()), child: const Text('إعادة التحقق من صلاحيات الحساب'))));
                return DashboardPage(onSignOut: widget.onSignOut, isHr: roleSnapshot.data == true);
              })
            : Scaffold(
                body: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.gpp_bad_outlined, size: 48),
                        const SizedBox(height: 12),
                        const Text('هذا الحساب غير مصرح له باستخدام نظام SWS.'),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: widget.onSignOut,
                          child: const Text('تسجيل الخروج'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
      );
    },
  );
}
