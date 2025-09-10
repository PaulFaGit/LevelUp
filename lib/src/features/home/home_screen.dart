import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:levelup/src/features/catalog/all_habits_screen.dart';
import 'package:levelup/src/features/settings/settings_screen.dart';
import 'package:levelup/src/shared/habit_card.dart';

import '../../shared/xp_logic.dart';
import '../../shared/widgets.dart';
import '../leaderboard/leaderboard_screen.dart';
import '../stats/stats_screen.dart';

// WICHTIG: Auth-Provider importieren, damit wir den Auth-State in den Streams beobachten
import '../auth/auth_gate.dart';

// ---------- Firestore-Streams hart an Auth binden + autoDispose ----------

final userDocProvider =
    StreamProvider.autoDispose<DocumentSnapshot<Map<String, dynamic>>?>((ref) {
  final auth = ref.watch(authStateChangesProvider);
  final user = auth.value;
  if (user == null) {
    // Kein User -> kein Firestore-Read
    return Stream<DocumentSnapshot<Map<String, dynamic>>?>.value(null);
  }
  final docRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
  return docRef.snapshots();
});

final habitsProvider =
    StreamProvider.autoDispose<QuerySnapshot<Map<String, dynamic>>>((ref) {
  final auth = ref.watch(authStateChangesProvider);
  final user = auth.value;
  if (user == null) {
    // leerer Stream solange abgemeldet
    return const Stream<QuerySnapshot<Map<String, dynamic>>>.empty();
  }
  return FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid)
      .collection('habits')
      .orderBy('title')
      .snapshots();
});

// ------------------------------ UI ------------------------------

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Defensive: Wenn doch mal ohne User gerendert wird, nichts Firestore-abhängiges anzeigen
    final auth = ref.watch(authStateChangesProvider);
    final user = auth.value;

    if (user == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final userDoc = ref.watch(userDocProvider);
    final habitsSnap = ref.watch(habitsProvider);

    return Scaffold(
      appBar: AppBar(
        leadingWidth: 56, // Platz für den Kreis
        leading: userDoc.when(
          data: (doc) {
            final data = doc?.data() ?? const <String, dynamic>{};
            final totalXP = (data['totalXP'] ?? 0) as int;
            final level = (data['totalLevel'] is int)
                ? data!['totalLevel'] as int
                : levelFromXP(totalXP);

            return Padding(
              padding: const EdgeInsets.only(left: 12),
              child: _LevelBadge(level: level),
            );
          },
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
        ),
        title: const Text('LevelUp!'),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const StatsScreen()),
            ),
            icon: const Icon(Icons.bar_chart),
            tooltip: 'Stats',
          ),
          IconButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const LeaderboardScreen()),
            ),
            icon: const Icon(Icons.emoji_events),
            tooltip: 'Leaderboard',
          ),
          IconButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
            icon: const Icon(Icons.settings),
            tooltip: 'Einstellungen',
          ),
          IconButton(
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
            },
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
        children: [
          // ---------- HEADER: Level + Kreis-Kategorien + Fortschrittsbalken ----------
          userDoc.when(
            data: (doc) {
              final data = doc?.data() ?? const <String, dynamic>{};
              final totalXP = (data['totalXP'] ?? 0) as int;
              final categoryXp =
                  Map<String, dynamic>.from(data['categoryXP'] ?? const {});
              final level = (data['totalLevel'] is int)
                  ? data!['totalLevel'] as int
                  : levelFromXP(totalXP);

              return _LevelHeaderCard(
                totalXp: totalXP,
                level: level,
                categoryXp: categoryXp,
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),

          const SizedBox(height: 16),

          // ---------- Favoriten ----------
          const Text(
            'Favoriten',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: Color(0xFFcbd5e1),
            ),
          ),
          habitsSnap.when(
            data: (qs) {
              final favorites =
                  qs.docs.where((d) => d.data()['favorite'] == true).toList();
              if (favorites.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8.0, vertical: 6),
                  child: Text(
                    'Noch keine Favoriten – füge welche hinzu ⭐',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xFF94a3b8)),
                  ),
                );
              }
              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: favorites.length,
                itemBuilder: (context, index) {
                  final userHabitDoc = favorites[index];
                  final userHabitData = userHabitDoc.data();

                  // Holen Sie die Katalogdaten, um die Beschreibungen zu ergänzen
                  return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                    // Die ID des Katalog-Habits ist dieselbe wie die ID des Benutzer-Habits
                    future: FirebaseFirestore.instance
                        .collection('catalog_habits')
                        .doc(userHabitDoc.id)
                        .get(),
                    builder: (context, catalogSnap) {
                      // Warten, bis die Katalogdaten geladen sind
                      if (!catalogSnap.hasData || !catalogSnap.data!.exists) {
                        return const Center(child: LinearProgressIndicator());
                      }
                      final catalogData = catalogSnap.data!.data();

                      // Kombinieren Sie die Benutzerdaten mit den Katalogdaten für die UI
                      final combinedData = {
                        ...catalogData!,
                        ...userHabitData,
                      };

                      return HabitCard(
                        habitRef: userHabitDoc.reference,
                        h: combinedData,
                      );
                    },
                  );
                },
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 12),
              );
            },
            loading: () => const LinearProgressIndicator(minHeight: 1),
            error: (e, _) => Text('Error: $e'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          if (!context.mounted) return;
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AllHabitsScreen()),
          );
        },
        backgroundColor: const Color(0xFF22d3ee),
        child: const Icon(Icons.add, color: Colors.black),
      ),
    );
  }
}

// ------------------------------ Neuer Header-Card ------------------------------

class _LevelHeaderCard extends StatelessWidget {
  const _LevelHeaderCard({
    required this.totalXp,
    required this.level,
    required this.categoryXp,
  });

  final int totalXp;
  final int level;
  final Map<String, dynamic> categoryXp;

  int _cumulative(int l) => 60 * l * (l + 1) ~/ 2;

  @override
  Widget build(BuildContext context) {
    // Fortschritt zum nächsten Level
    final currentBase = _cumulative(level);
    final nextNeed = _cumulative(level + 1);
    final span = (nextNeed - currentBase).clamp(1, 1 << 31);
    final progress = ((totalXp - currentBase) / span).clamp(0.0, 1.0);
    final toNext = nextNeed - totalXp;

    // Stufen-Icons wie im alten evolvingHero
    const stages = ['🌱', '🌿', '🌳', '🏯', '🚀', '🌌'];
    final stage = (level / 3).floor().clamp(0, 5);

    // Kategorie-Einträge sortieren (absteigend)
    final entries = categoryXp.entries
        .map((e) => MapEntry(
              e.key,
              (e.value is int)
                  ? e.value as int
                  : int.tryParse('${e.value}') ?? 0,
            ))
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // responsive Kreise: 3 per Row auf Phones, größer auf Tablets
    final width = MediaQuery.sizeOf(context).width;
    final isWide = width >= 700;
    final double circleSize = isWide ? 110 : 92;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0),
      child: glass(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Icon (oben zentriert)
            Text(stages[stage], style: const TextStyle(fontSize: 52)),
            const SizedBox(height: 8),

            // Level (zentriert)
            const Text('Level', style: TextStyle(color: Color(0xFF9fb3c8))),
            Text(
              '$level',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 26,
              ),
            ),
            const SizedBox(height: 4),

            // Total XP (zentriert)
            Text(
              '$totalXp XP insgesamt',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF9fb3c8)),
            ),

            const SizedBox(height: 14),

            // PROGRESS BAR (zentriert, breite 100%)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 12,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '$toNext XP bis Level-Up',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF9fb3c8)),
            ),

            // Kreise für Kategorien (zentriert, Wrap)
            if (entries.isNotEmpty) ...[
              const SizedBox(height: 18),
              _CategoryCircles(
                entries: entries,
                circleSize: circleSize,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ------------------------------ Kategorien: runde Badges ------------------------------

class _CategoryCircles extends StatelessWidget {
  const _CategoryCircles({
    required this.entries,
    required this.circleSize,
  });

  final List<MapEntry<String, int>> entries;
  final double circleSize;

  @override
  Widget build(BuildContext context) {
    // leichte Farbabstufung basierend auf Index
    Color tone(int i) {
      final base = Theme.of(context).colorScheme.surfaceVariant;
      // Nuancen über Opacity variieren:
      final t = 0.55 + 0.05 * (i % 5);
      return base.withOpacity(t.clamp(0.0, 0.9));
    }

    final textStyleLabel = Theme.of(context).textTheme.bodySmall?.copyWith(
          fontWeight: FontWeight.w700,
          color: const Color(0xFFdbeafe),
          letterSpacing: 0.2,
        );
    final textStyleXP = Theme.of(context).textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w800,
        );

    return Center(
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 12,
        runSpacing: 12,
        children: [
          for (int i = 0; i < entries.length; i++)
            _CategoryCircle(
              label: entries[i].key,
              xp: entries[i].value,
              size: circleSize,
              background: tone(i),
              textStyleLabel: textStyleLabel,
              textStyleXP: textStyleXP,
            ),
        ],
      ),
    );
  }
}

class _LevelBadge extends StatelessWidget {
  const _LevelBadge({required this.level});
  final int level;

  @override
  Widget build(BuildContext context) {
    final bg = Theme.of(context).colorScheme.surface;
    final border = Theme.of(context).dividerColor.withOpacity(0.35);

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: bg.withOpacity(0.6),
        shape: BoxShape.circle,
        border: Border.all(color: border, width: 2),
        boxShadow: const [
          BoxShadow(
            color: Colors.black38,
            blurRadius: 8,
            offset: Offset(0, 2),
          )
        ],
      ),
      child: Center(
        child: Text(
          '$level',
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}

class _CategoryCircle extends StatelessWidget {
  const _CategoryCircle({
    required this.label,
    required this.xp,
    required this.size,
    required this.background,
    required this.textStyleLabel,
    required this.textStyleXP,
  });

  final String label;
  final int xp;
  final double size;
  final Color background;
  final TextStyle? textStyleLabel;
  final TextStyle? textStyleXP;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: background,
        shape: BoxShape.circle,
        border: Border.all(
          color: Theme.of(context).dividerColor.withOpacity(0.25),
        ),
        boxShadow: const [
          BoxShadow(
            color: Colors.black45,
            blurRadius: 10,
            offset: Offset(0, 6),
          )
        ],
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label, textAlign: TextAlign.center, style: textStyleLabel),
                const SizedBox(height: 4),
                Text('$xp XP', textAlign: TextAlign.center, style: textStyleXP),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
