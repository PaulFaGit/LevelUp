import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

enum AuthMode { signIn, register }

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});
  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final formKey = GlobalKey<FormState>();
  final email = TextEditingController();
  final password = TextEditingController();
  final confirm = TextEditingController();

  bool loading = false;
  bool pwVisible = false;
  AuthMode mode = AuthMode.signIn;

  void _toggleMode() {
    setState(() {
      mode = (mode == AuthMode.signIn) ? AuthMode.register : AuthMode.signIn;
    });
  }

  String? _validateEmail(String? v) {
    if ((v ?? '').trim().isEmpty) return 'E-Mail angeben';
    final ok = RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(v!.trim());
    if (!ok) return 'Ungültige E-Mail';
    return null;
  }

  String? _validatePassword(String? v) {
    if ((v ?? '').isEmpty) return 'Passwort angeben';
    if ((v!).length < 6) return 'Mindestens 6 Zeichen';
    return null;
  }

  String? _validateConfirm(String? v) {
    if (mode == AuthMode.signIn) return null;
    if (v != password.text) return 'Passwörter stimmen nicht überein';
    return null;
  }

  Future<void> _submit() async {
    if (!formKey.currentState!.validate()) return;
    setState(() => loading = true);
    try {
      if (mode == AuthMode.signIn) {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email.text.trim(),
          password: password.text,
        );
      } else {
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email.text.trim(),
          password: password.text,
        );
        // optional: direkt E-Mail verifizieren
        // await FirebaseAuth.instance.currentUser?.sendEmailVerification();
      }
    } on FirebaseAuthException catch (e) {
      _showError(e.message ?? e.code);
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _google() async {
    setState(() => loading = true);
    try {
      if (kIsWeb) {
        // *** Web: Popup verwenden ***
        final provider = GoogleAuthProvider();
        await FirebaseAuth.instance.signInWithPopup(provider);
      } else {
        // *** Android/iOS: google_sign_in verwenden ***
        final g = await GoogleSignIn().signIn();
        if (g == null) return; // abgebrochen
        final auth = await g.authentication;
        final cred = GoogleAuthProvider.credential(
          idToken: auth.idToken,
          accessToken: auth.accessToken,
        );
        await FirebaseAuth.instance.signInWithCredential(cred);
      }
    } on FirebaseAuthException catch (e) {
      _showError(e.message ?? e.code);
    } catch (e) {
      _showError('Google Sign-In Fehler: $e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isRegister = mode == AuthMode.register;

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Card(
            elevation: 0,
            color: const Color(0xFF0f172a),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: Color(0xFF1f2937))),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('LevelUp!',
                        style: TextStyle(
                            fontSize: 28, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 10),
                    Text(isRegister ? 'Konto erstellen' : 'Anmelden',
                        style: const TextStyle(color: Color(0xFF93c5fd))),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: email,
                      validator: _validateEmail,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        hintText: 'E-Mail',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: password,
                      validator: _validatePassword,
                      obscureText: !pwVisible,
                      decoration: InputDecoration(
                        hintText: 'Passwort',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(pwVisible
                              ? Icons.visibility_off
                              : Icons.visibility),
                          onPressed: () =>
                              setState(() => pwVisible = !pwVisible),
                        ),
                      ),
                    ),
                    if (isRegister) ...[
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: confirm,
                        validator: _validateConfirm,
                        obscureText: true,
                        decoration: const InputDecoration(
                          hintText: 'Passwort bestätigen',
                          prefixIcon: Icon(Icons.lock_outline),
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: FilledButton(
                        onPressed: loading ? null : _submit,
                        child: Text(isRegister ? 'Registrieren' : 'Anmelden'),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(isRegister ? 'Schon ein Konto?' : 'Neu hier?'),
                        TextButton(
                            onPressed: loading ? null : _toggleMode,
                            child:
                                Text(isRegister ? 'Anmelden' : 'Registrieren')),
                      ],
                    ),
                    const Divider(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: OutlinedButton.icon(
                        onPressed: loading ? null : _google,
                        icon: const Icon(Icons.g_mobiledata),
                        label: const Text('Mit Google fortfahren'),
                      ),
                    ),
                    if (loading) ...[
                      const SizedBox(height: 16),
                      const LinearProgressIndicator(minHeight: 2),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
