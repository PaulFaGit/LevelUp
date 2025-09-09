import 'package:flutter/material.dart';

class CategoryXpRow extends StatelessWidget {
  const CategoryXpRow({
    super.key,
    required this.categoryXp,
    this.maxItems = 6,
    this.compact = false,
  });

  final Map<String, dynamic> categoryXp;
  final int maxItems;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (categoryXp.isEmpty) {
      return Text(
        'Noch keine Kategorie-XP',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
      );
    }

    // in List umwandeln, sortieren (absteigend nach XP)
    final entries = categoryXp.entries
        .map((e) => MapEntry(e.key, (e.value is int) ? e.value as int : int.tryParse('${e.value}') ?? 0))
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final shown = entries.take(maxItems).toList();
    final overflow = entries.length - shown.length;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final e in shown)
          _pill(context, e.key, e.value, compact: compact),
        if (overflow > 0)
          _morePill(context, overflow),
      ],
    );
  }

  Widget _pill(BuildContext context, String category, int xp, {required bool compact}) {
    final textTheme = Theme.of(context).textTheme;
    final label = compact ? '$category: $xp' : '$category • $xp XP';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.6),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _morePill(BuildContext context, int n) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.4),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.3)),
      ),
      child: Text(
        '+$n weitere',
        style: textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
      ),
    );
  }
}
