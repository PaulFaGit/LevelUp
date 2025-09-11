// lib/src/features/catalog/all_habits_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:levelup/src/shared/habit_card.dart'; // nutzt die refaktorierte HabitCard (habitRef + h + ensureExistsWith)
import 'package:levelup/src/shared/widgets.dart';

// ------------------------------------------------------------
// Firestore: Katalog-Stream (öffentlich)
// ------------------------------------------------------------
final catalogProvider =
    StreamProvider.autoDispose<QuerySnapshot<Map<String, dynamic>>>((ref) {
  return FirebaseFirestore.instance
      .collection('catalog_habits')
      .orderBy('category')
      .orderBy('title')
      .snapshots();
});

// ------------------------------------------------------------
// NEU: Firestore: ALLE Habits des Users streamen
// ------------------------------------------------------------
final allUserHabitsProvider =
    StreamProvider.autoDispose<Map<String, DocumentSnapshot<Map<String, dynamic>>>>((ref) {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    return const Stream.empty();
  }

  return FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid)
      .collection('habits')
      .snapshots()
      .map((qs) => {for (var doc in qs.docs) doc.id: doc});
});

// ------------------------------------------------------------
// Screen
// ------------------------------------------------------------
class AllHabitsScreen extends ConsumerStatefulWidget {
  const AllHabitsScreen({super.key});
  @override
  ConsumerState<AllHabitsScreen> createState() => _AllHabitsScreenState();
}

class _AllHabitsScreenState extends ConsumerState<AllHabitsScreen> {
  String? selectedCategory;

  @override
  Widget build(BuildContext context) {
    final catalogAsync = ref.watch(catalogProvider);
    final userHabitsAsync = ref.watch(allUserHabitsProvider);

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text('Alle Habits'),
      ),
      body: catalogAsync.when(
        loading: () => const LinearProgressIndicator(minHeight: 1),
        error: (e, _) => Center(child: Text('Fehler: $e')),
        data: (qs) {
          final docs = qs.docs;
          final userHabitDocs = userHabitsAsync.asData?.value ?? {};

          // Kategorien ableiten
          final categories = <String>{};
          for (final d in docs) {
            final c = (d.data()['category'] ?? '') as String;
            if (c.isNotEmpty) categories.add(c);
          }
          final catList = ['Alle', ...categories.toList()..sort()];

          // Filter anwenden
          final filtered =
              selectedCategory == null || selectedCategory == 'Alle'
                  ? docs
                  : docs
                      .where((d) => d.data()['category'] == selectedCategory)
                      .toList();

          final user = FirebaseAuth.instance.currentUser;

          return ListView(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
            children: [
              // Kategorie-Pills
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: catList.map((c) {
                    final sel = (selectedCategory ?? 'Alle') == c;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(c),
                        selected: sel,
                        onSelected: (_) => setState(
                          () => selectedCategory = c == 'Alle' ? null : c,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),

              // Kartenliste
              ...filtered.map((catalogDoc) {
                final catalogData = catalogDoc.data();
                final userHabitDoc = userHabitDocs[catalogDoc.id];
                final userHabitData = userHabitDoc?.data() ?? {};
                
                final combinedData = {
                  ...catalogData,
                  ...userHabitData,
                };

                // Ziel-Ref im User-Space
                final userHabitRef = (user == null)
                    ? FirebaseFirestore.instance.collection('_dummy').doc().withConverter<Map<String, dynamic>>(
                        fromFirestore: (s, _) => s.data() ?? <String, dynamic>{},
                        toFirestore: (m, _) => m,
                      )
                    : FirebaseFirestore.instance
                        .collection('users')
                        .doc(user.uid)
                        .collection('habits')
                        .doc(catalogDoc.id);

                final initialUserData = <String, dynamic>{
                  ...catalogData,
                  ...userHabitData,
                  'favorite': userHabitData['favorite'] ?? false,
                  'xp': userHabitData['xp'] ?? 0,
                  'streak': userHabitData['streak'] ?? 0,
                  'history': userHabitData['history'] ?? <String>[],
                  'todayLevel': userHabitData['todayLevel'] ?? 0,
                };

                if (user == null) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: glass(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Text((catalogData['emoji'] ?? '✨') as String,
                              style: const TextStyle(fontSize: 36)),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'Bitte anmelden, um Habits zu öffnen.',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: HabitCard(
                    habitRef: userHabitRef,
                    h: combinedData,
                    ensureExistsWith: initialUserData,
                  ),
                );
              }),

              if (filtered.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(12.0),
                  child: Text('Keine Habits in dieser Kategorie.'),
                ),
            ],
          );
        },
      ),
    );
  }
}