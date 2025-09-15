import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../shared/xp_logic.dart';
import '../home/widgets/level_overview.dart';

class UserProfileScreen extends StatelessWidget {
  const UserProfileScreen({
    super.key,
    required this.userId,
    this.initialDisplayName,
  });

  final String userId;
  final String? initialDisplayName;

  @override
  Widget build(BuildContext context) {
    final stream = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .snapshots();

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snapshot) {
        final doc = snapshot.data;
        final data = doc?.data();

        final displayName = (data?['displayName'] ?? initialDisplayName ?? 'Profil')
            .toString();

        int? level;
        int? totalXp;
        Map<String, dynamic>? categoryXp;

        if (doc != null && doc.exists && data != null) {
          totalXp = (data['totalXP'] ?? 0) as int;
          level = (data['totalLevel'] is int)
              ? data['totalLevel'] as int
              : levelFromXP(totalXp);
          categoryXp = Map<String, dynamic>.from(data['categoryXP'] ?? const {});
        }

        Widget body;
        if (snapshot.hasError) {
          body = Center(child: Text('Fehler: ${snapshot.error}'));
        } else if (!snapshot.hasData) {
          body = const Center(child: CircularProgressIndicator());
        } else if (doc == null || !doc.exists || data == null) {
          body = const Center(child: Text('Nutzer wurde nicht gefunden.'));
        } else {
          body = ListView(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 48),
            children: [
              UserLevelOverview(
                totalXp: totalXp!,
                level: level!,
                categoryXp: categoryXp!,
              ),
            ],
          );
        }

        Widget? leading;
        double? leadingWidth;

        if (Navigator.of(context).canPop()) {
          if (level == null) {
            leading = const BackButton();
          } else {
            leadingWidth = 96;
            leading = Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const BackButton(),
                const SizedBox(width: 4),
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: LevelBadge(level: level),
                ),
              ],
            );
          }
        } else if (level != null) {
          leadingWidth = 56;
          leading = Padding(
            padding: const EdgeInsets.only(left: 12),
            child: LevelBadge(level: level),
          );
        }

        return Scaffold(
          appBar: AppBar(
            leadingWidth: leadingWidth,
            leading: leading,
            title: Text(displayName),
            centerTitle: true,
          ),
          body: body,
        );
      },
    );
  }
}
