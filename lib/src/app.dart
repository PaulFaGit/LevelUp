import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'features/auth/auth_gate.dart';

Color _hex(String h) {
  final v = int.parse(h.replaceFirst('#', ''), radix: 16);
  return Color(0xFF000000 | v);
}

class LevelUpApp extends StatelessWidget {
  const LevelUpApp({super.key});
  @override
  Widget build(BuildContext context) {
    final base = ThemeData.dark(useMaterial3: true);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: base.copyWith(
        textTheme: GoogleFonts.interTextTheme(base.textTheme).apply(
          bodyColor: _hex('#e5e7eb'),
          displayColor: _hex('#e5e7eb'),
        ),
        scaffoldBackgroundColor: _hex('#070b11'),
        colorScheme: base.colorScheme.copyWith(
          primary: _hex('#22d3ee'),
          secondary: _hex('#93c5fd'),
        ),
      ),
      home: const AuthGate(),
    );
  }
}
