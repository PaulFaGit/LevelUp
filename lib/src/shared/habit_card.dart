// ------------------------------ Habit Card ------------------------------
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:levelup/src/features/habit/habit_screen.dart';
import 'package:levelup/src/shared/widgets.dart';
import 'package:levelup/src/shared/xp_logic.dart'; // <-- xpCluster-Widget hier importieren

class HabitCard extends ConsumerWidget {
  /// Referenz auf das **User-Habit** (users/{uid}/habits/{id})
  final DocumentReference<Map<String, dynamic>> habitRef;

  /// Daten des Habits (Map aus Firestore oder zusammengesetzt aus Katalog + Status)
  final Map<String, dynamic> h;

  /// Optional: Initialdaten, die beim ersten Tap idempotent in habitRef gemerged werden.
  /// Praktisch für die Overview (Katalog), damit der Habit im User-Space existiert,
  /// bevor der HabitScreen geöffnet wird.
  final Map<String, dynamic>? ensureExistsWith;

  const HabitCard({
    super.key,
    required this.habitRef,
    required this.h,
    this.ensureExistsWith,
  });

  /// Bequemer Factory-Ctor für die Main-Page, wenn du direkt einen Query-Dokument-Snapshot hast.
  factory HabitCard.fromSnapshot(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    return HabitCard(habitRef: doc.reference, h: doc.data());
  }

  Future<void> _toggleFavorite() async {
    final current = (h['favorite'] ?? false) as bool;
    try {
      await habitRef.update({'favorite': !current});
    } catch (_) {
      // Falls Doc noch nicht existiert: Merge schreiben
      await habitRef.set({'favorite': !current}, SetOptions(merge: true));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return InkWell(
      onTap: () async {
        if (ensureExistsWith != null) {
          // idempotent anlegen/mergen (z. B. aus Katalogdaten)
          await habitRef.set(ensureExistsWith!, SetOptions(merge: true));
        }
        if (!context.mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => HabitScreen(habitRef: habitRef)),
        );
      },
      child: glass(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              (h['emoji'] ?? '✨') as String,
              style: const TextStyle(fontSize: 36),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Titel
                  Text(
                    h['title'] ?? 'Habit',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),

                  // Kategorie + Streak (ohne "Lx"-Level-Anzeige)
                  Text(
                    '${h['category'] ?? ''} · 🔥 ${h['streak'] ?? 0}',
                    style: const TextStyle(color: Color(0xFF9ca3af)),
                  ),

                  // Beschreibung (falls vorhanden)
                  if ((h['description'] ?? '').toString().isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      '${h['description']}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],

                  const SizedBox(height: 8),

                  // Buttons-Cluster (S/M/L) – liest reqSmall/Medium/Large für die Subtexte
                  xpCluster(habitRef, h),
                ],
              ),
            ),

            // Favoriten-Stern
            IconButton(
              onPressed: _toggleFavorite,
              tooltip:
                  (h['favorite'] ?? false) ? 'Aus Favoriten entfernen' : 'Zu Favoriten',
              icon: Icon(
                (h['favorite'] ?? false) ? Icons.star : Icons.star_border,
              ),
              color: (h['favorite'] ?? false)
                  ? Colors.amber
                  : const Color(0xFF9ca3af),
            ),
          ],
        ),
      ),
    );
  }
}
