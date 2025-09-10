import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../shared/xp_logic.dart'; // enthält setTodayLevel und xpCluster
import '../../shared/widgets.dart'; // enthält glass()

class HabitScreen extends StatefulWidget {
  final DocumentReference<Map<String, dynamic>> habitRef;
  const HabitScreen({super.key, required this.habitRef});

  @override
  State<HabitScreen> createState() => _HabitScreenState();
}

class _HabitScreenState extends State<HabitScreen> {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: widget.habitRef.snapshots(),
      builder: (context, snap) {
        final data = snap.data?.data();
        if (data == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // Holt die Katalogdaten, um die Beschreibungen zu ergänzen
        return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          future: FirebaseFirestore.instance
              .collection('catalog_habits')
              .doc(widget.habitRef.id)
              .get(),
          builder: (context, catalogSnap) {
            if (!catalogSnap.hasData || !catalogSnap.data!.exists) {
              // Zeigt Lade-Indikator, bis Katalogdaten verfügbar sind
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }
            final catalogData = catalogSnap.data!.data();

            // Kombiniert Benutzerdaten mit den Katalogdaten für die vollständige Ansicht
            final combinedData = {
              ...catalogData!,
              ...data,
            };

            final title = (combinedData['title'] ?? 'Habit') as String;
            final emoji = (combinedData['emoji'] ?? '✨') as String;
            final category = (combinedData['category'] ?? '') as String;
            final streak = (combinedData['streak'] ?? 0) as int;
            final isFav = (combinedData['favorite'] ?? false) as bool;
            final description = (combinedData['description'] ?? '') as String;
            final history = (combinedData['history'] as List? ?? const [])
                .map((e) => e.toString())
                .toSet();

            return Scaffold(
              appBar: AppBar(
                title: Text(title),
                actions: [
                  IconButton(
                    tooltip: isFav ? 'Aus Favoriten entfernen' : 'Zu Favoriten',
                    onPressed: () =>
                        widget.habitRef.update({'favorite': !isFav}),
                    icon: Icon(isFav ? Icons.star : Icons.star_border),
                  ),
                ],
              ),
              body: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // --- Header-Karte ---
                  glass(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(emoji, style: const TextStyle(fontSize: 64)),
                        const SizedBox(height: 6),
                        Text(
                          '${category.isNotEmpty ? '$category · ' : ''}🔥 $streak',
                          style: const TextStyle(color: Color(0xFF9ca3af)),
                        ),
                        if (description.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(description, textAlign: TextAlign.center),
                        ],
                        const SizedBox(height: 12),
                        xpCluster(widget.habitRef, combinedData),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: () =>
                              widget.habitRef.update({'favorite': !isFav}),
                          icon: Icon(isFav ? Icons.star : Icons.star_border),
                          label: Text(isFav ? 'Favorit' : 'Zu Favoriten'),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // --- Historie: Monatskalender mit Navigation ---
                  const Text(
                    'Historie',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: Color(0xFFcbd5e1),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _MonthCalendar(history: history), // Korrigierter Aufruf
                ],
              ),
            );
          },
        );
      },
    );
  }
}

/// ========================= Monatskalender mit Navigation =========================
/// - Ganzer Monat sichtbar, Navigation (‹ / ›) + Heute
/// - Gemacht: 🔥 + Streak-Zahl an diesem Tag
/// - Nicht gemacht: ❌ (rotes Kreuz) – kein roter Hintergrund
/// - Zukunft: neutral
class _MonthCalendar extends StatefulWidget {
  const _MonthCalendar({required this.history});
  final Set<String>
      history; // ISO-UTC Tagesstrings, z. B. "2025-09-01T00:00:00.000Z"

  @override
  State<_MonthCalendar> createState() => _MonthCalendarState();
}

class _MonthCalendarState extends State<_MonthCalendar> {
  late DateTime _shownMonthFirstUtc;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now().toUtc();
    _shownMonthFirstUtc = DateTime.utc(now.year, now.month, 1);
  }

  String _isoUtc(DateTime d) =>
      DateTime.utc(d.year, d.month, d.day).toIso8601String();

  String _monthName(int m) {
    const names = [
      'Januar',
      'Februar',
      'März',
      'April',
      'Mai',
      'Juni',
      'Juli',
      'August',
      'September',
      'Oktober',
      'November',
      'Dezember'
    ];
    return names[m - 1];
  }

  int _initialStreakBefore(DateTime firstDayUtc) {
    int s = 0;
    DateTime cursor = firstDayUtc.subtract(const Duration(days: 1));
    while (widget.history.contains(_isoUtc(cursor))) {
      s++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return s;
  }

  void _prevMonth() {
    setState(() {
      _shownMonthFirstUtc = DateTime.utc(
          _shownMonthFirstUtc.year, _shownMonthFirstUtc.month - 1, 1);
    });
  }

  void _nextMonth() {
    setState(() {
      _shownMonthFirstUtc = DateTime.utc(
          _shownMonthFirstUtc.year, _shownMonthFirstUtc.month + 1, 1);
    });
  }

  void _goToday() {
    final now = DateTime.now().toUtc();
    setState(() {
      _shownMonthFirstUtc = DateTime.utc(now.year, now.month, 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    final firstDay = _shownMonthFirstUtc; // bereits UTC
    final now = DateTime.now().toUtc();
    final lastDay = DateTime.utc(firstDay.year, firstDay.month + 1, 0);
    final daysInMonth = lastDay.day;

    final leading = (firstDay.weekday + 6) % 7; // Mo=0, So=6
    final totalCells = leading + daysInMonth;
    final trailing = (totalCells % 7 == 0) ? 0 : (7 - (totalCells % 7));

    // Streak pro Tag berechnen (Serie kann aus Vormonat fortgesetzt werden)
    final streakPerDay = <int, int>{};
    int streakSoFar = _initialStreakBefore(firstDay);
    for (int day = 1; day <= daysInMonth; day++) {
      final date = DateTime.utc(firstDay.year, firstDay.month, day);
      final done = widget.history.contains(_isoUtc(date));
      if (done) {
        final prevDate = date.subtract(const Duration(days: 1));
        final prevDone = widget.history.contains(_isoUtc(prevDate));
        streakSoFar = prevDone ? (streakSoFar + 1) : 1;
        streakPerDay[day] = streakSoFar;
      } else {
        streakPerDay[day] = 0;
        streakSoFar = 0;
      }
    }

    final headerStyle = const TextStyle(
      fontWeight: FontWeight.w900,
      fontSize: 16,
    );

    final hintStyle = const TextStyle(
      color: Color(0xFF9fb3c8),
      fontWeight: FontWeight.w700,
    );

    Widget dayCell(int? dayNum) {
      if (dayNum == null) return const SizedBox.shrink();

      final date = DateTime.utc(firstDay.year, firstDay.month, dayNum);
      final iso = _isoUtc(date);
      final today = DateTime.utc(now.year, now.month, now.day);

      final isFuture = date.isAfter(today);
      final done = widget.history.contains(iso);
      final streak = streakPerDay[dayNum] ?? 0;

      final baseBorder = Border.all(color: const Color(0xFF1f2937));
      final radius = BorderRadius.circular(10);

      return Container(
        decoration: BoxDecoration(
          color: const Color(0xFF0b1220),
          border: baseBorder,
          borderRadius: radius,
        ),
        child: Stack(
          children: [
            // Tag-Nummer oben links
            Positioned(
              left: 6,
              top: 6,
              child: Text(
                '$dayNum',
                style: TextStyle(
                  fontSize: 12,
                  color: isFuture
                      ? const Color(0xFF374151)
                      : const Color(0xFF9ca3af),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            // Inhalt zentriert: 🔥 + Streak ODER ❌ ODER leer
            Center(
              child: () {
                if (done) {
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('🔥', style: TextStyle(fontSize: 18)),
                      const SizedBox(width: 4),
                      Text(
                        '$streak',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  );
                } else if (!isFuture) {
                  // nicht gemacht -> rotes Kreuz
                  return const Text(
                    '❌',
                    style: TextStyle(fontSize: 18),
                  );
                } else {
                  // Zukunft -> leer
                  return const SizedBox.shrink();
                }
              }(),
            ),
          ],
        ),
      );
    }

    return glass(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          // Kopfzeile mit Navigation
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                tooltip: 'Voriger Monat',
                onPressed: _prevMonth,
                icon: const Icon(Icons.chevron_left),
              ),
              Text(
                '${_monthName(firstDay.month)} ${firstDay.year}',
                style: headerStyle,
              ),
              Row(
                children: [
                  TextButton(
                    onPressed: _goToday,
                    child: const Text('Heute'),
                  ),
                  IconButton(
                    tooltip: 'Nächster Monat',
                    onPressed: _nextMonth,
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Wochentage (Mo–So)
          GridView.count(
            crossAxisCount: 7,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 1.8,
            children: const [
              Center(
                  child: Text('Mo',
                      style: TextStyle(
                          color: Color(0xFF9fb3c8),
                          fontWeight: FontWeight.w700))),
              Center(
                  child: Text('Di',
                      style: TextStyle(
                          color: Color(0xFF9fb3c8),
                          fontWeight: FontWeight.w700))),
              Center(
                  child: Text('Mi',
                      style: TextStyle(
                          color: Color(0xFF9fb3c8),
                          fontWeight: FontWeight.w700))),
              Center(
                  child: Text('Do',
                      style: TextStyle(
                          color: Color(0xFF9fb3c8),
                          fontWeight: FontWeight.w700))),
              Center(
                  child: Text('Fr',
                      style: TextStyle(
                          color: Color(0xFF9fb3c8),
                          fontWeight: FontWeight.w700))),
              Center(
                  child: Text('Sa',
                      style: TextStyle(
                          color: Color(0xFF9fb3c8),
                          fontWeight: FontWeight.w700))),
              Center(
                  child: Text('So',
                      style: TextStyle(
                          color: Color(0xFF9fb3c8),
                          fontWeight: FontWeight.w700))),
            ],
          ),

          // Tage-Raster
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: leading + daysInMonth + trailing,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
            ),
            itemBuilder: (context, index) {
              if (index < leading || index >= leading + daysInMonth) {
                return const SizedBox.shrink(); // leere Felder
              }
              final dayNum = index - leading + 1;
              return dayCell(dayNum);
            },
          ),
        ],
      ),
    );
  }
}
