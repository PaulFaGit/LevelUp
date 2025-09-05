import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import 'package:firebase_core/firebase_core.dart';
import 'package:LevelUp/HomeView.dart';
import 'firebase_options.dart';

import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:firebase_ui_auth/firebase_ui_auth.dart' as fb_ui;
import 'package:firebase_ui_oauth_google/firebase_ui_oauth_google.dart'
    as fb_google;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const LevelUpApp());
}

class LevelUpApp extends StatelessWidget {
  const LevelUpApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LevelUp',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF635BFF),
      ),
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<fb_auth.User?>(
      stream: fb_auth.FirebaseAuth.instance.authStateChanges(),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.active) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }
        final user = snap.data;
        return user == null ? const SignInView() : const HomeView();
      },
    );
  }
}

class SignInView extends StatefulWidget {
  const SignInView({super.key});
  @override
  State<SignInView> createState() => _SignInViewState();
}

class _SignInViewState extends State<SignInView> {
  bool staySignedIn = true;

  Future<void> _applyPersistence() async {
    if (!kIsWeb) return; // Mobile persistiert automatisch
    await fb_auth.FirebaseAuth.instance.setPersistence(
      staySignedIn ? fb_auth.Persistence.LOCAL : fb_auth.Persistence.SESSION,
    );
  }

  @override
  void initState() {
    super.initState();
    _applyPersistence(); // initial anwenden
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isWide = MediaQuery.of(context).size.width > 900;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [cs.primaryContainer, cs.secondaryContainer],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Material(
                color: Colors.transparent,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Container(
                    decoration: BoxDecoration(
                      color: cs.surface.withOpacity(0.6),
                      boxShadow: [
                        BoxShadow(
                            blurRadius: 32,
                            color: Colors.black.withOpacity(.12))
                      ],
                      border:
                          Border.all(color: cs.outlineVariant.withOpacity(.6)),
                    ),
                    child: isWide
                        // --- Web / breite Screens ---
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Flexible(
                                  flex: 1, fit: FlexFit.loose, child: _InfoPanel()),
                              Flexible(
                                flex: 1,
                                fit: FlexFit.loose,
                                child: _AuthPanel(
                                  staySignedIn: staySignedIn,
                                  onStayChanged: (v) async {
                                    setState(() => staySignedIn = v);
                                    await _applyPersistence();
                                  },
                                ),
                              ),
                            ],
                          )
                        // --- Mobile / schmale Screens ---
                        : _AuthPanel(
                            staySignedIn: staySignedIn,
                            onStayChanged: (v) async {
                              setState(() => staySignedIn = v);
                              await _applyPersistence();
                            },
                          ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoPanel extends StatelessWidget {
  const _InfoPanel();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(28, 32, 28, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: cs.primary.withOpacity(.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.trending_up, color: cs.primary),
            ),
            const SizedBox(width: 12),
            Text('LevelUp',
                style:
                    text.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
          ]),
          const SizedBox(height: 16),
          Text('Become your best self—together.',
              style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          const _Bullet(
              icon: Icons.check_circle,
              text: 'Build habits with a clean, focused UI'),
          const _Bullet(
              icon: Icons.group,
              text: 'Join public habits & compete on leaderboards'),
          const _Bullet(
              icon: Icons.local_fire_department,
              text: 'Visual streaks & progress calendar'),
          const SizedBox(height: 20),
          Text(
            'Secure by Firebase • Your data, your control',
            style: text.bodySmall?.copyWith(
              color:
                  Theme.of(context).textTheme.bodySmall?.color?.withOpacity(.7),
            ),
          ),
        ],
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet({required this.icon, required this.text});
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: cs.primary),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

class _AuthPanel extends StatelessWidget {
  const _AuthPanel({required this.staySignedIn, required this.onStayChanged});
  final bool staySignedIn;
  final ValueChanged<bool> onStayChanged;

  @override
  Widget build(BuildContext context) {
    final panel = fb_ui.SignInScreen(
      showAuthActionSwitch: true,
      providers: [
        fb_ui.EmailAuthProvider(),
        if (kIsWeb)
          fb_google.GoogleProvider(
            clientId:
                '209844004772-182aqv85tlse8p8h5em9d5k5832kdud3.apps.googleusercontent.com',
          )
        else
          fb_google.GoogleProvider(clientId: ''),
      ],
      headerBuilder: (context, constraints, action) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text('Welcome',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
          SizedBox(height: 6),
          Text('Sign in or create an account to continue.',
              style: TextStyle(fontSize: 13)),
        ],
      ),
      subtitleBuilder: (context, action) => const SizedBox.shrink(),
      footerBuilder: (context, action) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          Row(
            children: [
              Checkbox(
                value: staySignedIn,
                onChanged: (v) => onStayChanged(v ?? true),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4)),
              ),
              const SizedBox(width: 8),
              const Text('Stay signed in'),
            ],
          ),
          const SizedBox(height: 6),
          const Divider(),
          const SizedBox(height: 8),
          Text.rich(
            TextSpan(
              text: 'By continuing you agree to our ',
              children: [
                TextSpan(
                    text: 'Terms',
                    style: TextStyle(decoration: TextDecoration.underline)),
                const TextSpan(text: ' and '),
                TextSpan(
                    text: 'Privacy Policy',
                    style: TextStyle(decoration: TextDecoration.underline)),
              ],
            ),
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ),
    );

    return Container(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface.withOpacity(.85),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(blurRadius: 24, color: Colors.black.withOpacity(.1))
                ],
                border: Border.all(
                    color: Theme.of(context).colorScheme.outlineVariant),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 26, 24, 18),
                child: panel,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
