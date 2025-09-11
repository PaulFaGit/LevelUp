import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:levelup/src/shared/widgets.dart';

/// =============================================================
/// Level-Kurve (bestehende Logik bleibt erhalten)
/// cumulative(level) = 60 * level * (level + 1) / 2
/// =============================================================
int levelFromXP(int totalXP) {
  int level = 0;
  int threshold = 0;
  while (totalXP >= threshold) {
    level++;
    threshold = (level * (level + 1) * 60 ~/ 2);
  }
  return (level - 1).clamp(0, 9999);
}

/// =============================================================
/// Europe/Berlin Datum: Tagsschlüssel YYYY-MM-DD als ISO (UTC Mitternacht)
/// inkl. Sommer-/Winterzeit (CEST/CET) – ohne Zusatzpakete.
/// =============================================================

DateTime _lastSundayUtc(int year, int month) {
  final firstOfNextMonth = DateTime.utc(year, month + 1, 1);
  final lastDay = firstOfNextMonth.subtract(const Duration(days: 1));
  final delta = lastDay.weekday % 7; // So=7->0, Mo=1->1, ...
  return lastDay.subtract(Duration(days: delta));
}

int _berlinUtcOffsetHours(DateTime utcNow) {
  final year = utcNow.year;
  final lastSundayMarch = _lastSundayUtc(year, 3);
  final lastSundayOct = _lastSundayUtc(year, 10);

  // Wechselzeitpunkte in UTC (jeweils 01:00 UTC)
  final dstStart = DateTime.utc(year, 3, lastSundayMarch.day, 1, 0, 0);
  final dstEnd = DateTime.utc(year, 10, lastSundayOct.day, 1, 0, 0);

  final inDST = utcNow.isAfter(dstStart) && utcNow.isBefore(dstEnd);
  return inDST ? 2 : 1; // CEST=+2, CET=+1
}

/// Gibt den ISO-Tag (UTC-Mitternacht) für den aktuellen Tag in Berlin zurück.
String todayIsoBerlin() {
  final nowUtc = DateTime.now().toUtc();
  final off = _berlinUtcOffsetHours(nowUtc);
  final berlinNow = nowUtc.add(Duration(hours: off));
  final d = DateTime.utc(berlinNow.year, berlinNow.month, berlinNow.day);
  return d
      .toIso8601String(); // "YYYY-MM-DDTHH:MM:SS.mmmZ" mit Zeit=00:00:00.000Z
}

class _BerlinNow {
  final DateTime nowUtc;
  final String todayIso; // UTC-Mitternacht des Berliner Tages
  _BerlinNow(this.nowUtc, this.todayIso);
}

_BerlinNow _berlinNow() {
  final nowUtc = DateTime.now().toUtc();
  return _BerlinNow(nowUtc, todayIsoBerlin());
}

/// =============================================================
/// setTodayLevel: robust, transaktions-sicher, delta-basiert
/// newLevel: 0..3 (0=keins, 1=S, 2=M, 3=L)
///
/// Garantien:
/// - Delta wird ausschließlich aus dem aktuellen DB-Zustand berechnet.
/// - habit.xp fällt nie unter 0 (Delta wird ggf. gekappt).
/// - History/Streak nach Berlin-Zeit.
/// - **Invariante:** Nach dem Update gilt immer
///     users/{uid}.totalXP == Summe(user.categoryXP.*)
///   (wird in der Transaktion durch Neusummenbildung erzwungen).
/// =============================================================
Future<void> setTodayLevel(
  DocumentReference<Map<String, dynamic>> habitRef,
  Map<String, dynamic> h,
  int newLevel,
) async {
  final bn = _berlinNow();
  final clampedLevel = newLevel.clamp(0, 3);

  await FirebaseFirestore.instance.runTransaction((tx) async {
    // 1) Habit lesen
    final habitSnap = await tx.get(habitRef);
    if (!habitSnap.exists) return;
    final habit = habitSnap.data()!;

    // Aktueller Zustand maßgeblich aus DB
    // Datum prüfen: falls es ein anderer Tag ist, ist prevLevel 0.
    final String? prevIso = (habit['todayIso'] ?? '') as String;
    final int prevLevel = prevIso == bn.todayIso ? (habit['todayLevel'] ?? 0) as int : 0;
    
    if (prevLevel == clampedLevel) {
      // Nichts zu tun
      return;
    }

    // XP-Stufen (fallbacks auf h, dann defaults)
    final int xpSmall = (habit['xpSmall'] ?? h['xpSmall'] ?? 5) as int;
    final int xpMedium = (habit['xpMedium'] ?? h['xpMedium'] ?? 15) as int;
    final int xpLarge = (habit['xpLarge'] ?? h['xpLarge'] ?? 30) as int;
    final vals = [0, xpSmall, xpMedium, xpLarge];

    // Delta aus JETZT-Zustand
    final int baseDelta = vals[clampedLevel] - vals[prevLevel];

    // Aktuelle XP des Habits
    final int oldHabitXp = (habit['xp'] ?? 0) as int;

    // Delta ggf. kappen, damit XP nicht negativ werden können
    final int appliedDelta =
        (oldHabitXp + baseDelta) < 0 ? -oldHabitXp : baseDelta;
    final int newHabitXp = oldHabitXp + appliedDelta;

    // History (Tage) aktualisieren: nur hinzufügen, wenn 0 -> >0
    final Set<String> days = Set<String>.from(
      (habit['history'] as List?)?.map((e) => e.toString()) ?? const <String>[],
    );
    if (prevLevel == 0 && clampedLevel > 0) {
      days.add(bn.todayIso);
    }

    // Streak neu berechnen (rückwärts ab heute, Berlin-Tag als UTC-Mitternacht)
    int recomputeStreak(Set<String> d, String todayIso) {
      int s = 0;
      DateTime c = DateTime.parse(todayIso); // UTC
      while (d.contains(c.toIso8601String())) {
        s++;
        c = c.subtract(const Duration(days: 1));
      }
      return s;
    }

    final int newStreak = recomputeStreak(days, bn.todayIso);

    // Level aus neuer Habit-XP ableiten
    final int computedLevel = levelFromXP(newHabitXp);

    // 2) User-Dokument lesen (für Aggregation)
    final uid = habitRef.parent.parent!.id; // users/{uid}/habits/{hid}
    final userRef = habitRef.parent.parent!;
    final userSnap = await tx.get(userRef);
    final user = userSnap.data() ?? <String, dynamic>{};

    // categoryXP-Map robust lesen
    final Map<String, dynamic> rawCat =
        Map<String, dynamic>.from(user['categoryXP'] ?? const {});
    final Map<String, int> cat = {};
    for (final entry in rawCat.entries) {
      final v = entry.value;
      final asInt = (v is int) ? v : int.tryParse('$v') ?? 0;
      cat[entry.key] = asInt;
    }

    // Kategorie bestimmen
    final String category =
        (habit['category'] ?? h['category'] ?? 'uncategorized').toString();

    // Nur wenn appliedDelta != 0, Kategorie anpassen
    if (appliedDelta != 0) {
      cat[category] = (cat[category] ?? 0) + appliedDelta;
      if (cat[category]! < 0)
        cat[category] = 0; // Sicherheitsnetz, falls Alt-Daten negativ waren
    }

    // totalXP als Summe ALLER Kategorien setzen (harte Invariante)
    int newTotalXp = 0;
    cat.forEach((_, v) => newTotalXp += v);

    // 3) Updates schreiben
    // 3a) Habit-Dokument
    tx.update(habitRef, {
      'todayLevel': clampedLevel,
      'todayIso': bn.todayIso,
      'xp': newHabitXp,
      'level': computedLevel,
      'history': (days.toList()..sort()),
      'streak': newStreak,
      'lastDoneAt': Timestamp.fromDate(bn.nowUtc),
    });

    // 3b) User-Dokument (Aggregation)
    tx.set(
        userRef,
        {
          'categoryXP': cat,
          'totalXP': newTotalXp,
        },
        SetOptions(merge: true));
  });
}

/// =============================================================
/// UI: evolvingHero (unverändert nutzbar)
/// =============================================================
Widget evolvingHero(int totalXP) {
  final level = levelFromXP(totalXP);
  final toNext = ((level + 1) * (level + 2) * 60 ~/ 2) - totalXP;
  const stages = ['🌱', '🌿', '🌳', '🏯', '🚀', '🌌'];
  final stage = (level / 3).floor().clamp(0, 5);
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 12.0),
    child: glass(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Column(children: [
        Text(stages[stage], style: const TextStyle(fontSize: 56)),
        const SizedBox(height: 4),
        const Text('Level', style: TextStyle(color: Color(0xFF9fb3c8))),
        Text('$level',
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 22)),
        const SizedBox(height: 4),
        Text('$toNext XP bis Level-Up',
            style: const TextStyle(color: Color(0xFF9fb3c8))),
      ]),
    ),
  );
}

/// =============================================================
/// UI: xpCluster – Button-Cluster für Habits
/// =============================================================
Widget xpCluster(
  DocumentReference<Map<String, dynamic>> ref,
  Map<String, dynamic> h,
) {
  final String currentDayIso = todayIsoBerlin();
  final String? savedDayIso = h['todayIso'] as String?;
  // Das Level nur verwenden, wenn es vom heutigen Tag stammt.
  final int lvl = savedDayIso == currentDayIso ? (h['todayLevel'] ?? 0) as int : 0;
  
  // Anforderungen (req*) aus dem Habit lesen
  final String reqS = '${h['reqSmall'] ?? ''}';
  final String reqM = '${h['reqMedium'] ?? ''}';
  final String reqL = '${h['reqLarge'] ?? ''}';

  Widget btn(String label, String sub, bool active, VoidCallback onTap) =>
      InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: active ? const Color(0xFF1c2636) : const Color(0xFF0b1220),
            border: Border.all(color: const Color(0xFF1f2937)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: active ? const Color(0xFF22d3ee) : Colors.white,
                ),
              ),
              Text(
                sub,
                style: TextStyle(
                  fontSize: 11,
                  color: active
                      ? const Color(0xFF93c5fd)
                      : const Color(0xFF9ca3af),
                ),
              ),
            ],
          ),
        ),
      );

  return Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      btn('S · ${h['xpSmall']} XP', reqS, lvl >= 1, () {
        if (lvl == 1) {
          setTodayLevel(ref, h, 0);
        } else if (lvl == 0) {
          setTodayLevel(ref, h, 1);
        } else {
          setTodayLevel(ref, h, 1);
        }
      }),
      btn('M · ${h['xpMedium']} XP', reqM, lvl >= 2, () {
        if (lvl < 2) {
          setTodayLevel(ref, h, 2);
        } else if (lvl == 2) {
          setTodayLevel(ref, h, 1);
        } else if (lvl == 3) {
          setTodayLevel(ref, h, 2);
        }
      }),
      btn('L · ${h['xpLarge']} XP', reqL, lvl >= 3, () {
        if (lvl < 3) {
          setTodayLevel(ref, h, 3);
        } else {
          setTodayLevel(ref, h, 2);
        }
      }),
    ],
  );
}