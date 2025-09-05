import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class HabitService {
  HabitService(this._db, this._auth);
  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  String get _uid => _auth.currentUser!.uid;

  CollectionReference<Map<String, dynamic>> _habitsCol() =>
      _db.collection('users').doc(_uid).collection('habits');

  /// YYYY-MM-DD aus lokaler Zeit
  String today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day)
        .toIso8601String()
        .substring(0, 10);
  }

  Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>> watchHabits() {
    return _habitsCol().orderBy('name').snapshots().map((s) => s.docs);
  }

  Future<void> addHabit({required String name, String description = ''}) async {
    await _habitsCol().add({
      'name': name,
      'description': description,
      'currentStreak': 0,
      'longestStreak': 0,
      'lastDoneLocalDate': null,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Markiert heute erledigt ODER macht es rückgängig, inkl. Streak-Update (Transaktion)
  Future<void> toggleToday(String habitId) async {
    final t = today();
    final habitRef = _habitsCol().doc(habitId);
    final completionRef = habitRef.collection('completions').doc(t);

    await _db.runTransaction((tx) async {
      final snap = await tx.get(habitRef);
      if (!snap.exists) throw Exception('Habit not found');
      final data = snap.data()!;
      final last = data['lastDoneLocalDate'] as String?;
      int current = (data['currentStreak'] ?? 0) as int;
      int longest = (data['longestStreak'] ?? 0) as int;

      final compSnap = await tx.get(completionRef);
      final isDoneToday = compSnap.exists;

      if (!isDoneToday) {
        // heute erledigen
        final y = _yesterday(t);
        current = (last == y) ? current + 1 : 1;
        longest = max(longest, current);
        tx.set(completionRef, {'doneAt': FieldValue.serverTimestamp()});
        tx.update(habitRef, {
          'lastDoneLocalDate': t,
          'currentStreak': current,
          'longestStreak': longest,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        // heute rückgängig
        // nur wenn last == heute, sonst lassen wir Streak unverändert
        if (last == t) {
          current = max(0, current - 1);
          tx.update(habitRef, {
            'lastDoneLocalDate': _prevIfNeeded(last, t),
            'currentStreak': current,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
        tx.delete(completionRef);
      }
    });
  }

  String _yesterday(String yyyyMmDd) {
    final d = DateTime.parse(yyyyMmDd);
    final y = d.subtract(const Duration(days: 1));
    return y.toIso8601String().substring(0, 10);
  }

  String? _prevIfNeeded(String? last, String today) {
    // Beim Undo von heute setzen wir lastDoneLocalDate auf null,
    // weil wir keine Info über den Vortag aus dem Doc haben.
    if (last == today) return null;
    return last;
  }

  Stream<Map<String, dynamic>?> watchHabit(String habitId) {
    return _habitsCol().doc(habitId).snapshots().map((d) => d.data());
  }

  // Alle Completion-Daten (YYYY-MM-DD) für den Kalender
  Stream<Set<String>> watchCompletions(String habitId) {
    return _habitsCol()
        .doc(habitId)
        .collection('completions')
        .snapshots()
        .map((s) => s.docs.map((d) => d.id).toSet());
  }

  Future<void> updateHabit(String habitId,
      {required String name, String description = ''}) async {
    await _habitsCol().doc(habitId).update({
      'name': name,
      'description': description,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteHabit(String habitId) async {
    await _habitsCol().doc(habitId).delete();
  }

  Future<void> archiveHabit(String habitId) async {
    await _habitsCol().doc(habitId).update({'isArchived': true});
  }
}
