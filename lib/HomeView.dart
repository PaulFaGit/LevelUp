import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:firebase_ui_auth/firebase_ui_auth.dart' as fb_ui;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:LevelUp/habit_card.dart';
import 'package:LevelUp/habit_detail_page.dart';
import '../services/habit_service.dart';

class HomeView extends StatefulWidget {
  const HomeView({super.key});
  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  late final HabitService _service;

  @override
  void initState() {
    super.initState();
    _service =
        HabitService(FirebaseFirestore.instance, fb_auth.FirebaseAuth.instance);
  }

  Future<void> _createHabitDialog() async {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final res = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Neues Habit'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Titel')),
            TextField(
                controller: descCtrl,
                decoration: const InputDecoration(labelText: 'Beschreibung')),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Abbrechen')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Speichern')),
        ],
      ),
    );
    if (res == true && nameCtrl.text.trim().isNotEmpty) {
      await _service.addHabit(
          name: nameCtrl.text.trim(), description: descCtrl.text.trim());
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = fb_auth.FirebaseAuth.instance.currentUser!;
    return Scaffold(
      appBar: AppBar(
          title: const Text('LevelUp'), actions: const [fb_ui.SignOutButton()]),
      body: StreamBuilder<List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
        stream: _service.watchHabits(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snap.data!;
          // doneToday = existiert heute eine Completion?
          final today = _service.today();

          final openCount = docs.where((d) {
            // doneToday via completion subcollection prüfen:
            // Wir vermeiden Extra-Reads hier; einfacher Ansatz: vergleiche lastDoneLocalDate == today
            final last = d['lastDoneLocalDate'] as String?;
            return last != today;
          }).length;

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    'Du hast noch $openCount offene Habits für heute. Zieh es durch!',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Scrollbar(
                  thumbVisibility:
                      true, // Damit die Scrollbar immer sichtbar ist
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                    itemCount: docs.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (_, i) {
                      final d = docs[i].data();
                      final id = docs[i].id;
                      final name = (d['name'] as String?) ?? '';
                      final desc = (d['description'] as String?) ?? '';
                      final currentStreak =
                          (d['currentStreak'] as num?)?.toInt() ?? 0;
                      final last = d['lastDoneLocalDate'] as String?;
                      final doneToday = last == today;

                      return HabitCard(
                        title: name,
                        description: desc,
                        streak: currentStreak,
                        doneToday: doneToday,
                        onToggleToday: () => _service.toggleToday(id),
                        onTap: () {
                          Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => HabitDetailPage(habitId: id),
                              ));
                        },
                      );
                    },
                  ),
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createHabitDialog,
        child: const Icon(Icons.add),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}
