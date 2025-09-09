import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LeaderboardScreen extends StatelessWidget {
  const LeaderboardScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final users = FirebaseFirestore.instance.collection('users').orderBy('totalXP', descending: true).limit(100).snapshots();
    return Scaffold(
      appBar: AppBar(title: const Text('Rangliste')),
      body: StreamBuilder(
        stream: users,
        builder: (context, snap) {
          if (!snap.hasData) return const LinearProgressIndicator(minHeight: 1);
          final docs = (snap.data! as QuerySnapshot).docs;
          return ListView.separated(
            itemCount: docs.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final d = docs[i];
              return ListTile(
                leading: Text('#${i + 1}'),
                title: Text((d['displayName'] ?? 'User').toString()),
                subtitle: Text('${d['totalXP']} XP'),
              );
            },
          );
        },
      ),
    );
  }
}
