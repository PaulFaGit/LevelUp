import 'package:flutter/material.dart';
import 'package:levelup/src/shared/widgets.dart';
import 'package:levelup/src/shared/xp_logic.dart';

class UserLevelOverview extends StatelessWidget {
  const UserLevelOverview({
    super.key,
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
            Center(
              child: SizedBox(
                width: 200,
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
              CategoryProgressRow(entries: entries),
            ],
          ],
        ),
      ),
    );
  }
}

class CategoryProgressRow extends StatelessWidget {
  const CategoryProgressRow({
    super.key,
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
          final color =
              meta?['color'] ?? Theme.of(context).colorScheme.secondary;

          return CategoryProgressCard(
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

class CategoryProgressCard extends StatelessWidget {
  const CategoryProgressCard({
    super.key,
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

class LevelBadge extends StatelessWidget {
  const LevelBadge({
    super.key,
    required this.level,
  });

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
