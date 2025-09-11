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

final favoriteHabitDocsProvider =
    StreamProvider.autoDispose<QuerySnapshot<Map<String, dynamic>>>((ref) {
  final user = ref.watch(authStateChangesProvider).value;
  if (user == null) {
    return const Stream<QuerySnapshot<Map<String, dynamic>>>.empty();
  }
  return FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid)
      .collection('habits')
      .where('favorite', isEqualTo: true)
      .snapshots();
});


// ------------------------------ UI ------------------------------

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final userDoc = ref.watch(userDocProvider);
    final favoriteHabitsSnap = ref.watch(favoriteHabitDocsProvider);

    return Scaffold(
      appBar: AppBar(
        leadingWidth: 56,
        leading: userDoc.when(
          data: (doc) {
            final data = doc?.data() ?? const <String, dynamic>{};
            final totalXP = (data['totalXP'] ?? 0) as int;
            final level = levelFromXP(totalXP);

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

          const Text(
            'Favoriten',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: Color(0xFFcbd5e1),
            ),
          ),
          favoriteHabitsSnap.when(
            data: (qs) {
              final favorites = qs.docs;
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

                  return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                    future: FirebaseFirestore.instance
                        .collection('catalog_habits')
                        .doc(userHabitDoc.id)
                        .get(),
                    builder: (context, catalogSnap) {
                      if (!catalogSnap.hasData || !catalogSnap.data!.exists) {
                        return const Center(child: LinearProgressIndicator());
                      }
                      final catalogData = catalogSnap.data!.data();

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
        onPressed: () {
          Navigator.push(
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
    final currentBase = _cumulative(level);
    final nextNeed = _cumulative(level + 1);
    final span = (nextNeed - currentBase).clamp(1, 1 << 31);
    final progress = ((totalXp - currentBase) / span).clamp(0.0, 1.0);
    final toNext = nextNeed - totalXp;

    const stages = ['🌱', '🌿', '🌳', '🏯', '🚀', '🌌'];
    final stage = (level / 3).floor().clamp(0, 5);

    final entries = categoryXp.entries
        .map((e) => MapEntry(
              e.key,
              (e.value is int)
                  ? e.value as int
                  : int.tryParse('${e.value}') ?? 0,
            ))
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0),
      child: glass(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(stages[stage], style: const TextStyle(fontSize: 52)),
            const SizedBox(height: 8),

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

            const SizedBox(height: 14),
            
            // Gesamt-XP Balken kleiner machen und zentrieren
            Center(
              child: SizedBox(
                width: 200, // Feste, kleinere Breite
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 12,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 8),
            Text(
              '$toNext XP bis Level-Up',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF9fb3c8)),
            ),

            if (entries.isNotEmpty) ...[
              const SizedBox(height: 18),
              _CategoryProgressRow(entries: entries),
            ],
          ],
        ),
      ),
    );
  }
}

class _CategoryProgressRow extends StatelessWidget {
  const _CategoryProgressRow({
    required this.entries,
  });

  final List<MapEntry<String, int>> entries;

  static const _categoryMeta = <String, Map<String, dynamic>>{
    'Body': {'icon': Icons.fitness_center, 'color': Color(0xFF6C63FF)},
    'Mind': {'icon': Icons.psychology, 'color': Color(0xFF00BFA6)},
    'Social': {'icon': Icons.groups_rounded, 'color': Color(0xFFFB8C00)},
    'Wellness': {'icon': Icons.self_improvement, 'color': Color(0xFFEC407A)},
    'Work': {'icon': Icons.work, 'color': Color(0xFF42A5F5)},
  };

  @override
  Widget build(BuildContext context) {
    final sortedEntries = entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top5Entries = sortedEntries.take(5).toList();

    return Center(
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        alignment: WrapAlignment.center,
        children: top5Entries.map((entry) {
          final category = entry.key;
          final totalXp = entry.value;
          final level = levelFromXP(totalXp);
          final currentLevelStart = 60 * level * (level + 1) ~/ 2;
          final nextLevelXP = 60 * (level + 1) * (level + 2) ~/ 2;
          final xpInCurrentLevel = totalXp - currentLevelStart;
          final xpNeededForNextLevel = nextLevelXP - currentLevelStart;
          final progress = xpNeededForNextLevel > 0
              ? xpInCurrentLevel / xpNeededForNextLevel
              : 0.0;
          final remainingXp = nextLevelXP - totalXp;

          final meta = _categoryMeta[category];
          final iconData = meta?['icon'] ?? Icons.category;
          final color = meta?['color'] ?? Theme.of(context).colorScheme.secondary;

          return _CategoryProgressCard(
            category: category,
            level: level,
            totalXp: totalXp,
            remainingXp: remainingXp,
            progress: progress,
            iconData: iconData,
            color: color,
          );
        }).toList(),
      ),
    );
  }
}

class _CategoryProgressCard extends StatelessWidget {
  const _CategoryProgressCard({
    required this.category,
    required this.level,
    required this.totalXp,
    required this.remainingXp,
    required this.progress,
    required this.iconData,
    required this.color,
  });

  final String category;
  final int level;
  final int totalXp;
  final int remainingXp;
  final double progress;
  final IconData iconData;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: (MediaQuery.of(context).size.width / 2) - 24,
      constraints: const BoxConstraints(maxWidth: 150),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant.withOpacity(0.35),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outlineVariant, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(iconData, size: 24, color: color),
          const SizedBox(height: 8),
          Text(
            category,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium!.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Lvl $level',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              minHeight: 6,
              borderRadius: BorderRadius.circular(4),
              backgroundColor: color.withOpacity(0.3),
              color: color,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '+$remainingXp XP',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall!.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.7),
            ),
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
        ));
  }
}