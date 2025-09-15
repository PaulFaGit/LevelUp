import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:levelup/src/shared/xp_logic.dart';
import 'package:levelup/src/features/profile/user_profile_screen.dart';


class LeaderboardScreen extends StatelessWidget {
  const LeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;

    final stream = FirebaseFirestore.instance
        .collection('users')
        .orderBy('totalXP', descending: true)
        .limit(100)
        .snapshots();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rangliste'),
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: stream,
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(child: Text('Fehler: ${snap.error}'));
          }
          if (!snap.hasData) {
            return const LinearProgressIndicator(minHeight: 2);
          }
          final docs = snap.data!.docs;
          if (docs.isEmpty) {
            return const Center(child: Text('Noch keine Nutzer.'));
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, i) {
              final snap = docs[i];
              final data = snap.data();

              final isYou = currentUid != null && snap.id == currentUid;
              final displayName = (data['displayName'] ?? 'User').toString();
              final totalXP = (data['totalXP'] ?? 0) as int;
              final photoURL =
                  (data['photoURL'] ?? data['photoUrl'] ?? '') as String?;
              final categoryXP =
                  (data['categoryXP'] ?? const {}) as Map<String, dynamic>;

              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => UserProfileScreen(
                        userId: snap.id,
                        initialDisplayName: displayName,
                      ),
                    ),
                  );
                },
                child: _LeaderboardTile(
                  rank: i + 1,
                  isYou: isYou,
                  name: displayName,
                  photoURL: photoURL,
                  totalXP: totalXP,
                  categoryXP: {
                    'Body': (categoryXP['Body'] ?? 0) as num,
                    'Mind': (categoryXP['Mind'] ?? 0) as num,
                    'Social': (categoryXP['Social'] ?? 0) as num,
                    'Wellness': (categoryXP['Wellness'] ?? 0) as num,
                    'Work': (categoryXP['Work'] ?? 0) as num,
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _LeaderboardTile extends StatelessWidget {
  const _LeaderboardTile({
    required this.rank,
    required this.isYou,
    required this.name,
    required this.photoURL,
    required this.totalXP,
    required this.categoryXP,
  });

  final int rank;
  final bool isYou;
  final String name;
  final String? photoURL;
  final int totalXP;
  final Map<String, num> categoryXP;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final (rankLabel, rankStyle) = switch (rank) {
      1 => ('🥇', theme.textTheme.titleLarge!.copyWith(fontWeight: FontWeight.w900)),
      2 => ('🥈', theme.textTheme.titleLarge!.copyWith(fontWeight: FontWeight.w800)),
      3 => ('🥉', theme.textTheme.titleLarge!.copyWith(fontWeight: FontWeight.w800)),
      _ => ('#$rank', theme.textTheme.titleMedium!),
    };

    final cardColor = isYou
        ? theme.colorScheme.primaryContainer
        : theme.colorScheme.surfaceVariant.withOpacity(0.35);

    final borderColor =
        isYou ? theme.colorScheme.primary : theme.colorScheme.outlineVariant;

    final level = levelFromXP(totalXP);

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: isYou ? 2 : 1),
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
        children: [
          // Kopfzeile
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _RankBadge(text: rankLabel, isTop3: rank <= 3),
              const SizedBox(width: 12),
              CircleAvatar(
                radius: 22,
                backgroundImage: (photoURL != null && photoURL!.isNotEmpty)
                    ? NetworkImage(photoURL!)
                    : null,
                child: (photoURL == null || photoURL!.isEmpty)
                    ? Text(name.isNotEmpty ? name.characters.first.toUpperCase() : '?')
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium!.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (isYou) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary.withOpacity(.12),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(color: theme.colorScheme.primary),
                            ),
                            child: Text('Du', style: theme.textTheme.labelSmall),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Level $level · $totalXP XP',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Kategorie-Badges
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _categoryChips(context),
          ),
        ],
      ),
    );
  }

  List<Widget> _categoryChips(BuildContext context) {
    final theme = Theme.of(context);

    List<Widget> chips = [];
    for (final entry in _categoryMeta.entries) {
      final key = entry.key;
      final meta = entry.value;

      final xp = (categoryXP[key] ?? 0).toInt();
      final level = levelFromXP(xp);

      // Progress zum nächsten Level
      final nextThreshold =
          ((level + 1) * (level + 2) * 60 ~/ 2); // gleiche Formel wie in xplogic
      final prevThreshold =
          (level * (level + 1) * 60 ~/ 2); // cumulative(level)
      final progress =
          (xp - prevThreshold) / (nextThreshold - prevThreshold).clamp(1, 999999);

      chips.add(
        Container(
          width: 160,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: meta.color.withOpacity(.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: meta.color.withOpacity(.6)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(meta.icon, size: 16, color: meta.color),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      key,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelLarge!.copyWith(
                        fontWeight: FontWeight.w700,
                        color: meta.color,
                      ),
                    ),
                  ),
                  Text('Lvl $level', style: theme.textTheme.labelMedium),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  minHeight: 6,
                  value: progress.isNaN ? 0 : progress,
                  backgroundColor: meta.color.withOpacity(.18),
                  valueColor: AlwaysStoppedAnimation<Color>(meta.color),
                ),
              ),
              const SizedBox(height: 4),
              Text('$xp XP', style: theme.textTheme.labelSmall),
            ],
          ),
        ),
      );
    }
    return chips;
  }
}

class _RankBadge extends StatelessWidget {
  const _RankBadge({required this.text, required this.isTop3});
  final String text;
  final bool isTop3;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        gradient: isTop3
            ? LinearGradient(
                colors: [
                  theme.colorScheme.primary.withOpacity(.85),
                  theme.colorScheme.primaryContainer,
                ],
              )
            : null,
        color: isTop3 ? null : theme.colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: isTop3
            ? theme.textTheme.titleMedium!.copyWith(
                color: theme.colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.w800,
              )
            : theme.textTheme.titleMedium,
      ),
    );
  }
}

class _CatMeta {
  final IconData icon;
  final Color color;
  const _CatMeta(this.icon, this.color);
}

const _categoryMeta = <String, _CatMeta>{
  'Body': _CatMeta(Icons.fitness_center, Color(0xFF6C63FF)),
  'Mind': _CatMeta(Icons.psychology, Color(0xFF00BFA6)),
  'Social': _CatMeta(Icons.groups_rounded, Color(0xFFFB8C00)),
  'Wellness': _CatMeta(Icons.self_improvement, Color(0xFFEC407A)),
  'Work': _CatMeta(Icons.work, Color(0xFF42A5F5)),
};
