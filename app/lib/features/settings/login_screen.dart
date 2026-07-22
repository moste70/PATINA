import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/services/auth_service.dart';
import '../../shared/services/revenuecat_service.dart';
import '../../shared/pro/pro_gate.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailCtrl    = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _formKey      = GlobalKey<FormState>();

  bool _isLogin  = true;   // true = login, false = registrazione
  bool _loading  = false;
  bool _obscure  = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _loading = true);
    HapticFeedback.lightImpact();
    try {
      final cred = await ref.read(authServiceProvider).signInWithGoogle();
      if (cred == null) return; // annullato
      await RevenueCatService().identifyUser(cred.user!.uid);
      ref.read(proStatusProvider.notifier).onAuthChanged(cred.user!.uid);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppL10n.of(context).loginGoogleSignInFailed)),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    HapticFeedback.lightImpact();

    try {
      final auth = ref.read(authServiceProvider);
      UserCredential cred;

      if (_isLogin) {
        cred = await auth.signInWithEmail(
          _emailCtrl.text.trim(),
          _passwordCtrl.text,
        );
      } else {
        cred = await auth.registerWithEmail(
          _emailCtrl.text.trim(),
          _passwordCtrl.text,
        );
      }

      // Collega RevenueCat all'utente Firebase
      await RevenueCatService().identifyUser(cred.user!.uid);

      // Aggiorna subscription Firestore nel ProStatusNotifier
      ref.read(proStatusProvider.notifier).onAuthChanged(cred.user!.uid);

      if (mounted) Navigator.of(context).pop(true);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_authErrorMessage(AppL10n.of(context), e.code))),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resetPassword() async {
    final l = AppL10n.of(context);
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.loginEnterEmailForReset)),
      );
      return;
    }
    await ref.read(authServiceProvider).sendPasswordReset(email);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l.loginResetEmailSent)),
    );
  }

  String _authErrorMessage(AppL10n l, String code) => switch (code) {
        'user-not-found'       => l.loginErrorUserNotFound,
        'wrong-password'       => l.loginErrorWrongPassword,
        'email-already-in-use' => l.loginErrorEmailInUse,
        'weak-password'        => l.loginErrorWeakPassword,
        'invalid-email'        => l.loginErrorInvalidEmail,
        'network-request-failed' => l.loginErrorNetwork,
        _                      => l.loginErrorGeneric,
      };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tt     = Theme.of(context).textTheme;
    final l      = AppL10n.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isLogin ? l.loginTitleSignIn : l.loginTitleSignUp),
        centerTitle: false,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Icona Pro ──────────────────────────────────────────────
                  Icon(
                    Icons.workspace_premium_outlined,
                    size: 48,
                    color: scheme.primary,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _isLogin
                        ? l.loginWelcomeBack
                        : l.loginCreateAccountSubtitle,
                    style: tt.titleLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l.loginAccountRequiredHint,
                    style: tt.bodySmall?.copyWith(
                        color: scheme.onSurface.withOpacity(0.6)),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),

                  // ── Google Sign-In ─────────────────────────────────────────
                  OutlinedButton.icon(
                    onPressed: _loading ? null : _signInWithGoogle,
                    icon: const _GoogleLogo(),
                    label: Text(l.loginContinueWithGoogle),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Expanded(child: Divider()),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(l.loginOrDivider,
                            style: tt.bodySmall?.copyWith(
                                color: scheme.onSurface.withOpacity(0.5))),
                      ),
                      const Expanded(child: Divider()),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // ── Email ──────────────────────────────────────────────────
                  TextFormField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: l.loginEmailLabel,
                      prefixIcon: const Icon(Icons.email_outlined),
                    ),
                    validator: (v) => (v == null || !v.contains('@'))
                        ? l.loginEmailInvalid
                        : null,
                  ),
                  const SizedBox(height: 16),

                  // ── Password ───────────────────────────────────────────────
                  TextFormField(
                    controller: _passwordCtrl,
                    obscureText: _obscure,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _submit(),
                    decoration: InputDecoration(
                      labelText: l.loginPasswordLabel,
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(_obscure
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined),
                        onPressed: () =>
                            setState(() => _obscure = !_obscure),
                      ),
                    ),
                    validator: (v) => (v == null || v.length < 6)
                        ? l.loginPasswordMinChars
                        : null,
                  ),
                  const SizedBox(height: 8),

                  // ── Password dimenticata ───────────────────────────────────
                  if (_isLogin)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _resetPassword,
                        child: Text(l.loginForgotPassword),
                      ),
                    ),

                  const SizedBox(height: 24),

                  // ── Submit ─────────────────────────────────────────────────
                  FilledButton(
                    onPressed: _loading ? null : _submit,
                    child: _loading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(_isLogin ? l.loginTitleSignIn : l.loginTitleSignUp),
                  ),
                  const SizedBox(height: 16),

                  // ── Toggle login/registrazione ────────────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _isLogin
                            ? l.loginNoAccount
                            : l.loginHaveAccount,
                        style: tt.bodySmall,
                      ),
                      TextButton(
                        onPressed: () =>
                            setState(() => _isLogin = !_isLogin),
                        child: Text(_isLogin ? l.loginSignUpAction : l.loginTitleSignIn),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GoogleLogo extends StatelessWidget {
  const _GoogleLogo();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(size: const Size(20, 20), painter: _GoogleLogoPainter());
  }
}

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final c = size.width / 2;
    final paint = Paint()..style = PaintingStyle.fill;

    // G shape semplificata con i 4 colori Google
    paint.color = const Color(0xFF4285F4);
    canvas.drawArc(Rect.fromCircle(center: Offset(c, c), radius: c),
        -1.57, 3.14, false, paint..style = PaintingStyle.stroke
          ..strokeWidth = size.width * 0.22
          ..color = const Color(0xFF4285F4));

    paint
      ..style = PaintingStyle.fill
      ..color = const Color(0xFF4285F4);
    canvas.drawRect(
        Rect.fromLTWH(c, c - size.height * 0.14, c, size.height * 0.28),
        paint);

    paint.color = const Color(0xFFEA4335);
    canvas.drawArc(Rect.fromCircle(center: Offset(c, c), radius: c),
        -1.57, -1.57, false,
        paint..style = PaintingStyle.stroke..strokeWidth = size.width * 0.22);

    paint.color = const Color(0xFF34A853);
    canvas.drawArc(Rect.fromCircle(center: Offset(c, c), radius: c),
        0, 1.57, false,
        paint..style = PaintingStyle.stroke..strokeWidth = size.width * 0.22);

    paint.color = const Color(0xFFFBBC05);
    canvas.drawArc(Rect.fromCircle(center: Offset(c, c), radius: c),
        1.57, 1.57, false,
        paint..style = PaintingStyle.stroke..strokeWidth = size.width * 0.22);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
