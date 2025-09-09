import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../shared/widgets.dart';

class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final users = FirebaseFirestore.instance.collection('users');
    return Scaffold(
      appBar: AppBar(title: const Text('Statistik')),
      body: FutureBuilder<QuerySnapshot<Map<String, dynamic>>>(
        future: users.get(),
        builder: (context, snap) {
          if (!snap.hasData) return const LinearProgressIndicator(minHeight: 1);
          final docs = snap.data!.docs;
          final total = docs.fold<int>(0, (s, d) => s + (d['totalXP'] ?? 0) as int);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              glass(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text('Gesamt', style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFFcbd5e1))),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 24, top: 8),
                child: Text('$total XP'),
              )
            ],
          );
        },
      ),
    );
  }
}
