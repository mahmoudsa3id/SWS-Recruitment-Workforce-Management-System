import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/di/injection.dart';
import '../../../core/theme/app_theme.dart';
import 'cubit/auth_cubit.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({super.key, required this.onSignedIn});
  final VoidCallback onSignedIn;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<AuthCubit>(),
      child: _LoginView(onSignedIn: onSignedIn),
    );
  }
}

class _LoginView extends StatefulWidget {
  const _LoginView({required this.onSignedIn});
  final VoidCallback onSignedIn;

  @override
  State<_LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<_LoginView> {
  final email = TextEditingController();
  final password = TextEditingController();
  bool obscure = true;

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (email.text.trim().isEmpty || password.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('أدخل البريد الإلكتروني وكلمة المرور.')),
      );
      return;
    }
    await context.read<AuthCubit>().signIn(email.text.trim(), password.text);
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthCubit, AuthState>(
      listener: (context, state) {
        if (state is AuthSignedIn) widget.onSignedIn();
        if (state is AuthFailure) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(state.message)));
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text(' سجل دخولك للإدارة SWS'),
          centerTitle: true,
          backgroundColor: Colors.transparent,
        ),
        backgroundColor: AppTheme.cream,
        body: LayoutBuilder(
          builder: (context, constraints) {
            final desktop = constraints.maxWidth >= 920;
            final form = Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(desktop ? 44 : 22),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 470),
                  child: Card(
                    child: Padding(
                      padding: EdgeInsets.all(desktop ? 36 : 26),
                      child: BlocBuilder<AuthCubit, AuthState>(
                        builder: (context, state) {
                          final busy = state is AuthLoading;
                          return AutofillGroup(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Container(
                                  height: 68,
                                  width: 68,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      begin: Alignment.topRight,
                                      end: Alignment.bottomLeft,
                                      colors: [AppTheme.green2, AppTheme.green],
                                    ),
                                    borderRadius: BorderRadius.circular(21),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppTheme.green.withValues(
                                          alpha: .18,
                                        ),
                                        blurRadius: 22,
                                        offset: const Offset(0, 10),
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.account_balance_rounded,
                                    color: Colors.white,
                                    size: 34,
                                  ),
                                ),
                                const SizedBox(height: 26),
                                Text(
                                  'مرحبًا بعودتك',
                                  style: Theme.of(
                                    context,
                                  ).textTheme.headlineMedium,
                                ),
                                const SizedBox(height: 7),
                                const Text(
                                  'سجّل الدخول لإدارة ملفات المسافرين والحسابات.',
                                  style: TextStyle(
                                    color: AppTheme.muted,
                                    height: 1.6,
                                  ),
                                ),
                                const SizedBox(height: 28),
                                TextField(
                                  controller: email,
                                  keyboardType: TextInputType.emailAddress,
                                  autofillHints: const [AutofillHints.username],
                                  decoration: const InputDecoration(
                                    labelText: 'البريد الإلكتروني',
                                    prefixIcon: Icon(
                                      Icons.alternate_email_rounded,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 14),
                                TextField(
                                  controller: password,
                                  obscureText: obscure,
                                  autofillHints: const [AutofillHints.password],
                                  onSubmitted: (_) {
                                    if (!busy) _submit();
                                  },
                                  decoration: InputDecoration(
                                    labelText: 'كلمة المرور',
                                    prefixIcon: const Icon(
                                      Icons.lock_outline_rounded,
                                    ),
                                    suffixIcon: IconButton(
                                      tooltip: obscure
                                          ? 'إظهار كلمة المرور'
                                          : 'إخفاء كلمة المرور',
                                      onPressed: () =>
                                          setState(() => obscure = !obscure),
                                      icon: Icon(
                                        obscure
                                            ? Icons.visibility_outlined
                                            : Icons.visibility_off_outlined,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 22),
                                FilledButton(
                                  onPressed: busy ? null : _submit,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 3,
                                    ),
                                    child: busy
                                        ? const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                        : const Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                Icons.login_rounded,
                                                size: 19,
                                              ),
                                              SizedBox(width: 10),
                                              Text('دخول الإدارة'),
                                            ],
                                          ),
                                  ),
                                ),
                                const SizedBox(height: 18),
                                const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.verified_user_outlined,
                                      size: 16,
                                      color: AppTheme.green3,
                                    ),
                                    SizedBox(width: 7),
                                    Flexible(
                                      child: Text(
                                        'الوصول مخصص لحساب أدمن نشط ومعتمد.',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: AppTheme.muted,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            );

            if (!desktop) {
              return Stack(
                children: [
                  const Positioned(
                    top: -110,
                    left: -90,
                    child: _GlowCircle(size: 270, color: AppTheme.paleGreen),
                  ),
                  const Positioned(
                    bottom: -130,
                    right: -100,
                    child: _GlowCircle(size: 300, color: AppTheme.paleGold),
                  ),
                  form,
                ],
              );
            }

            return Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topRight,
                        end: Alignment.bottomLeft,
                        colors: [AppTheme.green, Color(0xFF0C2E26)],
                      ),
                    ),
                    child: Stack(
                      children: [
                        const Positioned(
                          top: -90,
                          left: -90,
                          child: _GlowCircle(
                            size: 330,
                            color: Color(0x223FC49A),
                          ),
                        ),
                        const Positioned(
                          bottom: -130,
                          right: -110,
                          child: _GlowCircle(
                            size: 390,
                            color: Color(0x22C7A56B),
                          ),
                        ),
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.all(52),
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 520),
                              child: const Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _BrandMark(large: true),
                                  SizedBox(height: 36),
                                  Text(
                                    'إدارة أوضح.\nقرارات أدق.',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 42,
                                      height: 1.35,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  SizedBox(height: 16),
                                  Text(
                                    'منصة موحدة لإدارة المسافرين، المستندات، التحصيلات، المصروفات والمرتبات.',
                                    style: TextStyle(
                                      color: Color(0xFFD4E4DD),
                                      fontSize: 16,
                                      height: 1.9,
                                    ),
                                  ),
                                  SizedBox(height: 32),
                                  _FeatureLine(
                                    icon: Icons.shield_outlined,
                                    label: 'صلاحيات إدارة محمية',
                                  ),
                                  SizedBox(height: 14),
                                  _FeatureLine(
                                    icon: Icons.receipt_long_outlined,
                                    label: 'حسابات وتقارير مترابطة',
                                  ),
                                  SizedBox(height: 14),
                                  _FeatureLine(
                                    icon: Icons.folder_open_outlined,
                                    label: 'أرشيف ملفات منظم',
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(child: form),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark({this.large = false});
  final bool large;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: large ? 58 : 46,
          height: large ? 58 : 46,
          decoration: BoxDecoration(
            color: AppTheme.gold,
            borderRadius: BorderRadius.circular(large ? 18 : 14),
          ),
          child: Icon(
            Icons.account_balance_rounded,
            color: AppTheme.green,
            size: large ? 32 : 25,
          ),
        ),
        const SizedBox(width: 14),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'SWS',
              style: TextStyle(
                color: large ? Colors.white : AppTheme.green,
                fontSize: large ? 28 : 22,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
              ),
            ),
            Text(
              'شمس الإبداع',
              style: TextStyle(
                color: large ? const Color(0xFFD4E4DD) : AppTheme.muted,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _FeatureLine extends StatelessWidget {
  const _FeatureLine({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, color: AppTheme.gold, size: 21),
      const SizedBox(width: 12),
      Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    ],
  );
}

class _GlowCircle extends StatelessWidget {
  const _GlowCircle({required this.size, required this.color});
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    ),
  );
}
