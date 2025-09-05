import 'package:flutter/material.dart';

class HabitCard extends StatelessWidget {
  const HabitCard({
    super.key,
    required this.title,
    required this.description,
    required this.streak,
    required this.doneToday,
    required this.onToggleToday,
    this.onTap,
  });

  final String title;
  final String description;
  final int streak;
  final bool doneToday; // abgeleitet: gibt es heute eine Completion?
  final VoidCallback onToggleToday;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                  color: Colors.black.withOpacity(.06))
            ],
            border: Border.all(color: cs.outlineVariant),
          ),
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Textblock
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    Text(
                      description,
                      style: TextStyle(
                        color: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.color
                            ?.withOpacity(.8),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Icon(Icons.local_fire_department,
                            size: 18, color: Colors.deepOrange),
                        const SizedBox(width: 4),
                        Text('$streak',
                            style:
                                const TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(width: 6),
                        const Text('Streak'),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Toggle-Button (Check für erledigen, Cross für undo)
              FilledButton(
                onPressed: onToggleToday,
                style: FilledButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  backgroundColor: doneToday ? cs.tertiary : cs.primary,
                  foregroundColor: cs.onPrimary,
                ),
                child: Icon(doneToday ? Icons.close : Icons.check),
              ),
            ],
          ),
        ));
  }
}
