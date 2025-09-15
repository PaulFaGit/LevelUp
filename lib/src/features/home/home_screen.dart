import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:levelup/src/features/catalog/all_habits_screen.dart';
import 'package:levelup/src/features/settings/settings_screen.dart';
import 'package:levelup/src/shared/habit_card.dart';

import '../../shared/xp_logic.dart';
import '../friends/friends_screen.dart';
import '../leaderboard/leaderboard_screen.dart';
import '../stats/stats_screen.dart';
import 'widgets/level_overview.dart';

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
              child: LevelBadge(level: level),
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
              MaterialPageRoute(builder: (_) => const FriendsScreen()),
            ),
            icon: const Icon(Icons.group),
            tooltip: 'Freunde',
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

              return UserLevelOverview(
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
