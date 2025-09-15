import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../shared/xp_logic.dart';
import '../home/widgets/level_overview.dart';
import '../friends/friend_service.dart';

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
              const SizedBox(height: 24),
              FriendActionSection(
                profileUserId: userId,
                profileDisplayName: displayName,
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

class FriendActionSection extends StatelessWidget {
  const FriendActionSection({
    super.key,
    required this.profileUserId,
    required this.profileDisplayName,
  });

  final String profileUserId;
  final String profileDisplayName;

  @override
  Widget build(BuildContext context) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUid == null || currentUid == profileUserId) {
      return const SizedBox.shrink();
    }

    final friendDocStream = FirebaseFirestore.instance
        .collection('users')
        .doc(currentUid)
        .collection('friends')
        .doc(profileUserId)
        .snapshots();

    final showSnack = (String message) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    };

    void handleError(Object error) {
      final message = error is FriendServiceException
          ? error.message
          : 'Etwas ist schiefgelaufen.';
      showSnack(message);
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: friendDocStream,
      builder: (context, snapshot) {
        final isFriend = snapshot.data?.exists ?? false;

        if (isFriend) {
          return Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.check_circle_outline),
              label: const Text('Freunde – entfernen?'),
              onPressed: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (context) {
                    return AlertDialog(
                      title: const Text('Freund entfernen'),
                      content: Text(
                        'Möchtest du $profileDisplayName wirklich entfernen?',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          child: const Text('Abbrechen'),
                        ),
                        ElevatedButton(
                          onPressed: () => Navigator.of(context).pop(true),
                          child: const Text('Entfernen'),
                        ),
                      ],
                    );
                  },
                );

                if (confirmed == true) {
                  try {
                    await FriendService.removeFriend(profileUserId);
                    showSnack('$profileDisplayName wurde entfernt.');
                  } catch (error) {
                    handleError(error);
                  }
                }
              },
            ),
          );
        }

        final pair = FriendService.pairKey(currentUid, profileUserId);
        final requestStream = FirebaseFirestore.instance
            .collection('friend_requests')
            .where('pairKey', isEqualTo: pair)
            .where('status', isEqualTo: 'pending')
            .limit(1)
            .snapshots();

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: requestStream,
          builder: (context, requestSnapshot) {
            if (!requestSnapshot.hasData) {
              return const SizedBox.shrink();
            }

            if (requestSnapshot.data!.docs.isEmpty) {
              return Align(
                alignment: Alignment.centerLeft,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.person_add_alt_1),
                  label: const Text('Freund hinzufügen'),
                  onPressed: () async {
                    try {
                      await FriendService.sendFriendRequest(profileUserId);
                      showSnack('Anfrage gesendet.');
                    } catch (error) {
                      handleError(error);
                    }
                  },
                ),
              );
            }

            final requestDoc = requestSnapshot.data!.docs.first;
            final data = requestDoc.data();
            final fromUserId = (data['fromUserId'] ?? '') as String;
            final toUserId = (data['toUserId'] ?? '') as String;

            if (toUserId == currentUid) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$profileDisplayName hat dir eine Anfrage geschickt.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () async {
                            try {
                              await FriendService.declineFriendRequest(
                                requestDoc.id,
                              );
                              showSnack('Anfrage abgelehnt.');
                            } catch (error) {
                              handleError(error);
                            }
                          },
                          child: const Text('Ablehnen'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            try {
                              await FriendService.acceptFriendRequest(
                                requestDoc.id,
                              );
                              showSnack('Ihr seid jetzt befreundet.');
                            } catch (error) {
                              handleError(error);
                            }
                          },
                          child: const Text('Annehmen'),
                        ),
                      ),
                    ],
                  ),
                ],
              );
            }

            if (fromUserId == currentUid) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Anfrage an $profileDisplayName gesendet.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  TextButton(
                    onPressed: () async {
                      try {
                        await FriendService.cancelFriendRequest(requestDoc.id);
                        showSnack('Anfrage zurückgezogen.');
                      } catch (error) {
                        handleError(error);
                      }
                    },
                    child: const Text('Anfrage zurückziehen'),
                  ),
                ],
              );
            }

            return const SizedBox.shrink();
          },
        );
      },
    );
  }
}
