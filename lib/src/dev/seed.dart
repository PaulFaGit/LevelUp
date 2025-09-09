// lib/src/dev/seed.dart
import 'package:cloud_firestore/cloud_firestore.dart';

String _slug(String s) {
  const map = {'ä':'ae','ö':'oe','ü':'ue','Ä':'Ae','Ö':'Oe','Ü':'Ue','ß':'ss'};
  final mapped = s.split('').map((c) => map[c] ?? c).join();
  final lower = mapped.toLowerCase();
  final keep = RegExp(r'[a-z0-9]+');
  return keep.allMatches(lower).map((m)=>m.group(0)).join('-');
}

/// Einmalig ausführen, um catalog_habits zu befüllen (idempotent).
Future<void> seedCatalogHabits() async {
  final db = FirebaseFirestore.instance;
  final batch = db.batch();

  final List<Map<String, dynamic>> items = [
    // ---------- MIND ----------
    {
      'category': 'Mind',
      'title': 'Lesen',
      'description': 'Regelmäßig lesen – fokussiert und ohne Ablenkung.',
      'emoji': '📚',
      'xpSmall': 5, 'xpMedium': 15, 'xpLarge': 30,
      'reqSmall': '5 Seiten', 'reqMedium': '10 Seiten', 'reqLarge': '20 Seiten',
    },
    {
      'category': 'Mind',
      'title': 'Meditation',
      'description': 'Achtsamkeit trainieren – Atem beobachten, Gedanken ziehen lassen.',
      'emoji': '🧘',
      'xpSmall': 5, 'xpMedium': 15, 'xpLarge': 30,
      'reqSmall': '5 Min', 'reqMedium': '10 Min', 'reqLarge': '20 Min',
    },
    {
      'category': 'Mind',
      'title': 'Sprachen lernen',
      'description': 'Vokabeln & Sprechen – konsistent neue Lektionen.',
      'emoji': '🗣️',
      'xpSmall': 5, 'xpMedium': 15, 'xpLarge': 30,
      'reqSmall': '1 Lektion (~10 Min)', 'reqMedium': '2 Lektionen (~20 Min)', 'reqLarge': '3 Lektionen (~30 Min)',
    },
    {
      'category': 'Mind',
      'title': 'Schreiben/Journaling',
      'description': 'Gedanken klarziehen, reflektieren, Ziele festhalten.',
      'emoji': '✍️',
      'xpSmall': 5, 'xpMedium': 15, 'xpLarge': 30,
      'reqSmall': '5 Min / ~50 Wörter', 'reqMedium': '10 Min / ~150 Wörter', 'reqLarge': '20 Min / ~300 Wörter',
    },
    {
      'category': 'Mind',
      'title': 'Online-Kurs',
      'description': 'Fortschritt in einem Kurs deiner Wahl.',
      'emoji': '💻',
      'xpSmall': 5, 'xpMedium': 15, 'xpLarge': 30,
      'reqSmall': '1 Modul (~15 Min)', 'reqMedium': '2 Module (~30 Min)', 'reqLarge': '3 Module (~45 Min)',
    },

    // ---------- BODY ----------
    {
      'category': 'Body',
      'title': 'Krafttraining',
      'description': 'Grundübungen & volle ROM – sauber, progressiv.',
      'emoji': '🏋️',
      'xpSmall': 10, 'xpMedium': 25, 'xpLarge': 50,
      'reqSmall': '10 Min', 'reqMedium': '25 Min', 'reqLarge': '45+ Min',
    },
    {
      'category': 'Body',
      'title': 'Laufen/Cardio',
      'description': 'Locker starten, Pace später steigern.',
      'emoji': '🏃',
      'xpSmall': 8, 'xpMedium': 20, 'xpLarge': 40,
      'reqSmall': '1 km', 'reqMedium': '3 km', 'reqLarge': '5+ km',
    },
    {
      'category': 'Body',
      'title': 'Mobility/Stretching',
      'description': 'Beweglichkeit & Haltung – kurze tägliche Sessions.',
      'emoji': '🧘‍♂️',
      'xpSmall': 5, 'xpMedium': 15, 'xpLarge': 30,
      'reqSmall': '5 Min', 'reqMedium': '10 Min', 'reqLarge': '20 Min',
    },
    {
      'category': 'Body',
      'title': 'Wasser trinken',
      'description': 'Konstant hydratisiert bleiben.',
      'emoji': '💧',
      'xpSmall': 2, 'xpMedium': 5, 'xpLarge': 10,
      'reqSmall': '0,5 L', 'reqMedium': '1 L', 'reqLarge': '2 L',
    },
    {
      'category': 'Body',
      'title': 'Schlafhygiene',
      'description': 'Abendroutine, kein Screen, konstante Zeiten.',
      'emoji': '😴',
      'xpSmall': 5, 'xpMedium': 15, 'xpLarge': 30,
      'reqSmall': 'Licht/Screen ↓ (15 Min)', 'reqMedium': 'Abendroutine (30 Min)', 'reqLarge': '8h Schlaf im Fenster',
    },

    // ---------- WORK ----------
    {
      'category': 'Work',
      'title': 'Deep Work',
      'description': 'Ablenkungsfrei konzentriert an einer Sache arbeiten.',
      'emoji': '🧠',
      'xpSmall': 10, 'xpMedium': 30, 'xpLarge': 60,
      'reqSmall': '25 Min Fokus', 'reqMedium': '50 Min Fokus', 'reqLarge': '90 Min Fokus',
    },
    {
      'category': 'Work',
      'title': 'Aufgaben-Review',
      'description': 'To-Do aktualisieren, planen, priorisieren.',
      'emoji': '🗂️',
      'xpSmall': 5, 'xpMedium': 12, 'xpLarge': 24,
      'reqSmall': 'Grobplanung (5–10 Min)', 'reqMedium': 'Tagesplan (15 Min)', 'reqLarge': 'Wochenplan (30 Min)',
    },
    {
      'category': 'Work',
      'title': 'Inbox Zero',
      'description': 'Posteingang aufräumen & sortieren.',
      'emoji': '📥',
      'xpSmall': 5, 'xpMedium': 15, 'xpLarge': 30,
      'reqSmall': '10 Mails / 10 Min', 'reqMedium': '25 Mails / 20 Min', 'reqLarge': 'Inbox leer / 30 Min',
    },
    {
      'category': 'Work',
      'title': 'Skill/Coding',
      'description': 'Zielgerichtetes Skill-Training (z. B. Code-Katas).',
      'emoji': '💡',
      'xpSmall': 8, 'xpMedium': 20, 'xpLarge': 40,
      'reqSmall': '15 Min Übung', 'reqMedium': '30 Min Übung', 'reqLarge': '60 Min Übung',
    },
    {
      'category': 'Work',
      'title': 'Projekt-Block',
      'description': 'Ein definierter Block an einem Projekt.',
      'emoji': '🧱',
      'xpSmall': 8, 'xpMedium': 20, 'xpLarge': 40,
      'reqSmall': '15 Min', 'reqMedium': '30 Min', 'reqLarge': '60 Min',
    },

    // ---------- SOCIAL ----------
    {
      'category': 'Social',
      'title': 'Freund kontaktieren',
      'description': 'Kurzer Check-in, ehrlich & persönlich.',
      'emoji': '💬',
      'xpSmall': 5, 'xpMedium': 12, 'xpLarge': 24,
      'reqSmall': 'Kurze Nachricht', 'reqMedium': 'Telefonat (15 Min)', 'reqLarge': 'Treffen (30+ Min)',
    },
    {
      'category': 'Social',
      'title': 'Netzwerken',
      'description': 'Beziehungen pflegen, Mehrwert bieten.',
      'emoji': '🤝',
      'xpSmall': 5, 'xpMedium': 15, 'xpLarge': 30,
      'reqSmall': '1 Nachricht/Intro', 'reqMedium': 'Call (15–20 Min)', 'reqLarge': 'Meeting (30+ Min)',
    },
    {
      'category': 'Social',
      'title': 'Familie-Zeit',
      'description': 'Quality Time ohne Handy.',
      'emoji': '👨‍👩‍👧‍👦',
      'xpSmall': 5, 'xpMedium': 15, 'xpLarge': 30,
      'reqSmall': '5–10 Min', 'reqMedium': '15–30 Min', 'reqLarge': '30–60 Min',
    },
    {
      'category': 'Social',
      'title': 'Community-Beitrag',
      'description': 'Hilf jemandem öffentlich (Forum, Gruppe, Repo).',
      'emoji': '🌐',
      'xpSmall': 5, 'xpMedium': 15, 'xpLarge': 30,
      'reqSmall': 'Kommentar/Antwort', 'reqMedium': 'Nützlicher Beitrag', 'reqLarge': 'Guide/Tutorial',
    },
    {
      'category': 'Social',
      'title': 'Dankbarkeit',
      'description': 'Bewusst Danke sagen/schreiben.',
      'emoji': '🙏',
      'xpSmall': 3, 'xpMedium': 9, 'xpLarge': 18,
      'reqSmall': '1 Nachricht', 'reqMedium': '3 Nachrichten', 'reqLarge': '5 Nachrichten',
    },

    // ---------- WELLNESS ----------
    {
      'category': 'Wellness',
      'title': 'Spazieren',
      'description': 'Frische Luft, Tempo egal – Hauptsache raus.',
      'emoji': '🚶',
      'xpSmall': 5, 'xpMedium': 12, 'xpLarge': 24,
      'reqSmall': '10 Min', 'reqMedium': '20 Min', 'reqLarge': '40 Min',
    },
    {
      'category': 'Wellness',
      'title': 'Gesund kochen',
      'description': 'Selbst kochen – vollwertig & ausgewogen.',
      'emoji': '🥗',
      'xpSmall': 6, 'xpMedium': 15, 'xpLarge': 30,
      'reqSmall': 'Snack/klein', 'reqMedium': 'Mahlzeit', 'reqLarge': 'Meal Prep (2+ Portionen)',
    },
    {
      'category': 'Wellness',
      'title': 'Digital Detox',
      'description': 'Bewusst offline sein.',
      'emoji': '📵',
      'xpSmall': 5, 'xpMedium': 12, 'xpLarge': 24,
      'reqSmall': '15 Min ohne Social', 'reqMedium': '30 Min', 'reqLarge': '60 Min',
    },
    {
      'category': 'Wellness',
      'title': 'Atemübungen',
      'description': 'Box-Breathing / 4–4–4–4 oder 4–7–8.',
      'emoji': '🌬️',
      'xpSmall': 3, 'xpMedium': 9, 'xpLarge': 18,
      'reqSmall': '2 Min', 'reqMedium': '5 Min', 'reqLarge': '10 Min',
    },
    {
      'category': 'Wellness',
      'title': 'Haushalt',
      'description': 'Kurzer Block Ordnung/Putzen/Wäsche.',
      'emoji': '🧹',
      'xpSmall': 5, 'xpMedium': 12, 'xpLarge': 24,
      'reqSmall': '10 Min', 'reqMedium': '20 Min', 'reqLarge': '40 Min',
    },
  ];

  for (final h in items) {
    final id = '${_slug(h['category'] as String)}_${_slug(h['title'] as String)}';
    final doc = db.collection('catalog_habits').doc(id);
    batch.set(doc, h, SetOptions(merge: true));
  }

  await batch.commit();
}
