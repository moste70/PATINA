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
        SnackBar(content: Text(_authErrorMessage(e.code))),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resetPassword() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Inserisci la tua email per reimpostare la password.')),
      );
      return;
    }
    await ref.read(authServiceProvider).sendPasswordReset(email);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Email di reimpostazione inviata.')),
    );
  }

  String _authErrorMessage(String code) => switch (code) {
        'user-not-found'       => 'Nessun account trovato con questa email.',
        'wrong-password'       => 'Password errata.',
        'email-already-in-use' => 'Esiste già un account con questa email.',
        'weak-password'        => 'La password deve essere di almeno 6 caratteri.',
        'invalid-email'        => 'Indirizzo email non valido.',
        'network-request-failed' => 'Errore di rete. Controlla la connessione.',
        _                      => 'Errore di autenticazione. Riprova.',
      };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tt     = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isLogin ? 'Accedi' : 'Crea account'),
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
                        ? 'Bentornato in Patina Pro'
                        : 'Crea il tuo account Patina',
                    style: tt.titleLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'L\'account è necessario per attivare e sincronizzare il tuo abbonamento Pro.',
                    style: tt.bodySmall?.copyWith(
                        color: scheme.onSurface.withOpacity(0.6)),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),

                  // ── Email ──────────────────────────────────────────────────
                  TextFormField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                    validator: (v) => (v == null || !v.contains('@'))
                        ? 'Email non valida'
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
                      labelText: 'Password',
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
                        ? 'Minimo 6 caratteri'
                        : null,
                  ),
                  const SizedBox(height: 8),

                  // ── Password dimenticata ───────────────────────────────────
                  if (_isLogin)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _resetPassword,
                        child: const Text('Password dimenticata?'),
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
                        : Text(_isLogin ? 'Accedi' : 'Crea account'),
                  ),
                  const SizedBox(height: 16),

                  // ── Toggle login/registrazione ────────────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _isLogin
                            ? 'Non hai un account?'
                            : 'Hai già un account?',
                        style: tt.bodySmall,
                      ),
                      TextButton(
                        onPressed: () =>
                            setState(() => _isLogin = !_isLogin),
                        child: Text(_isLogin ? 'Registrati' : 'Accedi'),
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
