import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:levelup/src/features/friends/friend_service.dart';
import 'package:levelup/src/features/profile/user_profile_screen.dart';
import 'package:levelup/src/shared/xp_logic.dart';

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  Timer? _debounce;
  bool _isSearching = false;
  List<FriendSearchResult> _searchResults = const [];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _searchFocusNode.addListener(() {
      if (!_searchFocusNode.hasFocus) {
        setState(() => _searchResults = const []);
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final text = _searchController.text.trim();
    _debounce?.cancel();

    if (text.isEmpty) {
      setState(() {
        _isSearching = false;
        _searchResults = const [];
      });
      return;
    }

    _debounce = Timer(const Duration(seconds: 1), () {
      _performSearch(text);
    });
  }

  Future<void> _performSearch(String query) async {
    setState(() {
      _isSearching = true;
    });

    try {
      final results = await FriendService.searchUsers(query);
      if (!mounted) return;
      if (_searchController.text.trim() == query.trim()) {
        setState(() {
          _searchResults = results;
        });
      }
    } catch (error) {
      if (!mounted) return;
      _handleError(error);
    } finally {
      if (mounted) {
        setState(() {
          _isSearching = false;
        });
      }
    }
  }

  void _handleError(Object error) {
    final message = error is FriendServiceException
        ? error.message
        : 'Etwas ist schiefgelaufen.';
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _openProfile(FriendSearchResult user) {
    FocusScope.of(context).unfocus();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => UserProfileScreen(
          userId: user.userId,
          initialDisplayName: user.displayName,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;

    if (currentUid == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Freunde'),
          centerTitle: true,
        ),
        body: const Center(
          child: Text('Bitte melde dich an, um Freunde zu verwalten.'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Freunde'),
        centerTitle: true,
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.translucent,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            const Text(
              'Freunde suchen',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            _buildSearchField(),
            const SizedBox(height: 24),
            _IncomingRequestsSection(
              currentUserId: currentUid,
              onError: _handleError,
              onInfo: _showMessage,
            ),
            const SizedBox(height: 24),
            _OutgoingRequestsSection(
              currentUserId: currentUid,
              onError: _handleError,
              onInfo: _showMessage,
            ),
            const SizedBox(height: 24),
            _FriendListSection(
              currentUserId: currentUid,
              onError: _handleError,
              onInfo: _showMessage,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchField() {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _searchController,
          focusNode: _searchFocusNode,
          decoration: InputDecoration(
            hintText: 'Name eingeben …',
            prefixIcon: const Icon(Icons.search),
            filled: true,
            fillColor: theme.colorScheme.surfaceVariant.withOpacity(0.25),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: theme.colorScheme.outlineVariant),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: theme.colorScheme.outlineVariant),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.6),
            ),
          ),
        ),
        if (_isSearching)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: LinearProgressIndicator(minHeight: 2),
          ),
        if (_searchResults.isNotEmpty && _searchFocusNode.hasFocus)
          Container(
            margin: const EdgeInsets.only(top: 8),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceVariant.withOpacity(0.35),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: theme.colorScheme.outlineVariant),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemBuilder: (context, index) {
                final result = _searchResults[index];
                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _openProfile(result),
                    child: Padding(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundImage: (result.photoUrl != null &&
                                    result.photoUrl!.isNotEmpty)
                                ? NetworkImage(result.photoUrl!)
                                : null,
                            child: (result.photoUrl == null ||
                                    result.photoUrl!.isEmpty)
                                ? Text(
                                    result.displayName.isNotEmpty
                                        ? result.displayName.characters.first
                                            .toUpperCase()
                                        : '?',
                                  )
                                : null,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  result.displayName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${result.totalXp} XP',
                                  style: theme.textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right),
                        ],
                      ),
                    ),
                  ),
                );
              },
              separatorBuilder: (_, __) => Divider(
                height: 1,
                color: theme.colorScheme.outlineVariant.withOpacity(0.4),
              ),
              itemCount: _searchResults.length,
            ),
          ),
      ],
    );
  }
}

class _IncomingRequestsSection extends StatelessWidget {
  const _IncomingRequestsSection({
    required this.currentUserId,
    required this.onError,
    required this.onInfo,
  });

  final String currentUserId;
  final void Function(Object error) onError;
  final void Function(String message) onInfo;

  @override
  Widget build(BuildContext context) {
    final stream = FirebaseFirestore.instance
        .collection('friend_requests')
        .where('toUserId', isEqualTo: currentUserId)
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .snapshots();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Text('Fehler beim Laden der Anfragen: ${snapshot.error}');
        }
        if (!snapshot.hasData) {
          return const LinearProgressIndicator(minHeight: 2);
        }

        final docs = snapshot.data!.docs;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Eingehende Anfragen',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            if (docs.isEmpty)
              Text(
                'Keine neuen Anfragen.',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: Colors.white70),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemBuilder: (context, index) {
                  final doc = docs[index];
                  return _FriendRequestTile(
                    requestDoc: doc,
                    isIncoming: true,
                    onAccept: () async {
                      try {
                        await FriendService.acceptFriendRequest(doc.id);
                        onInfo('Anfrage akzeptiert.');
                      } catch (error) {
                        onError(error);
                      }
                    },
                    onDecline: () async {
                      try {
                        await FriendService.declineFriendRequest(doc.id);
                        onInfo('Anfrage abgelehnt.');
                      } catch (error) {
                        onError(error);
                      }
                    },
                  );
                },
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemCount: docs.length,
              ),
          ],
        );
      },
    );
  }
}

class _OutgoingRequestsSection extends StatelessWidget {
  const _OutgoingRequestsSection({
    required this.currentUserId,
    required this.onError,
    required this.onInfo,
  });

  final String currentUserId;
  final void Function(Object error) onError;
  final void Function(String message) onInfo;

  @override
  Widget build(BuildContext context) {
    final stream = FirebaseFirestore.instance
        .collection('friend_requests')
        .where('fromUserId', isEqualTo: currentUserId)
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .snapshots();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Text('Fehler beim Laden der Anfragen: ${snapshot.error}');
        }
        if (!snapshot.hasData) {
          return const LinearProgressIndicator(minHeight: 2);
        }

        final docs = snapshot.data!.docs;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Ausgehende Anfragen',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            if (docs.isEmpty)
              Text(
                'Keine offenen Anfragen.',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: Colors.white70),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemBuilder: (context, index) {
                  final doc = docs[index];
                  return _FriendRequestTile(
                    requestDoc: doc,
                    isIncoming: false,
                    onCancel: () async {
                      try {
                        await FriendService.cancelFriendRequest(doc.id);
                        onInfo('Anfrage entfernt.');
                      } catch (error) {
                        onError(error);
                      }
                    },
                  );
                },
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemCount: docs.length,
              ),
          ],
        );
      },
    );
  }
}

class _FriendListSection extends StatelessWidget {
  const _FriendListSection({
    required this.currentUserId,
    required this.onError,
    required this.onInfo,
  });

  final String currentUserId;
  final void Function(Object error) onError;
  final void Function(String message) onInfo;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<FriendUser>>(
      stream: FriendService.friendsStream(currentUserId),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Text('Fehler beim Laden der Freunde: ${snapshot.error}');
        }
        if (!snapshot.hasData) {
          return const LinearProgressIndicator(minHeight: 2);
        }

        final friends = snapshot.data!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Deine Freunde',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            if (friends.isEmpty)
              Text(
                'Noch keine Freunde hinzugefügt.',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: Colors.white70),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: friends.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final friend = friends[index];
                  return _FriendTile(
                    friend: friend,
                    rank: index + 1,
                    onRemove: () async {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (context) {
                          return AlertDialog(
                            title: const Text('Freund entfernen?'),
                            content: Text(
                              'Möchtest du ${friend.displayName} wirklich aus deiner Freundesliste entfernen?',
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
                          await FriendService.removeFriend(friend.userId);
                          onInfo('${friend.displayName} wurde entfernt.');
                        } catch (error) {
                          onError(error);
                        }
                      }
                    },
                  );
                },
              ),
          ],
        );
      },
    );
  }
}

class _FriendRequestTile extends StatelessWidget {
  const _FriendRequestTile({
    required this.requestDoc,
    required this.isIncoming,
    this.onAccept,
    this.onDecline,
    this.onCancel,
  });

  final QueryDocumentSnapshot<Map<String, dynamic>> requestDoc;
  final bool isIncoming;
  final Future<void> Function()? onAccept;
  final Future<void> Function()? onDecline;
  final Future<void> Function()? onCancel;

  @override
  Widget build(BuildContext context) {
    final data = requestDoc.data();
    final userId = isIncoming
        ? (data['fromUserId'] ?? '') as String
        : (data['toUserId'] ?? '') as String;

    final userStream = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .snapshots();

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: userStream,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const LinearProgressIndicator(minHeight: 1);
        }

        final userDoc = snapshot.data!;
        final userData = userDoc.data() ?? const <String, dynamic>{};
        final displayName =
            (userData['displayName'] ?? 'Nutzer').toString();
        final photoUrl =
            (userData['photoURL'] ?? userData['photoUrl'] ?? '') as String?;
        final totalXp = (userData['totalXP'] ?? 0) as int;
        final level = levelFromXP(totalXp);

        return Material(
          color: Theme.of(context)
              .colorScheme
              .surfaceVariant
              .withOpacity(0.35),
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => UserProfileScreen(
                    userId: userDoc.id,
                    initialDisplayName: displayName,
                  ),
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundImage: (photoUrl != null && photoUrl.isNotEmpty)
                            ? NetworkImage(photoUrl)
                            : null,
                        child: (photoUrl == null || photoUrl.isEmpty)
                            ? Text(
                                displayName.isNotEmpty
                                    ? displayName.characters.first.toUpperCase()
                                    : '?',
                              )
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              displayName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Level $level · $totalXp XP',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (isIncoming)
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: onDecline,
                            child: const Text('Ablehnen'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: onAccept,
                            child: const Text('Annehmen'),
                          ),
                        ),
                      ],
                    )
                  else
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: onCancel,
                        child: const Text('Anfrage zurückziehen'),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _FriendTile extends StatelessWidget {
  const _FriendTile({
    required this.friend,
    required this.rank,
    required this.onRemove,
  });

  final FriendUser friend;
  final int rank;
  final Future<void> Function() onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final level = levelFromXP(friend.totalXp);

    return Material(
      color: theme.colorScheme.surfaceVariant.withOpacity(0.35),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => UserProfileScreen(
                userId: friend.userId,
                initialDisplayName: friend.displayName,
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              _RankBadge(rank: rank),
              const SizedBox(width: 12),
              CircleAvatar(
                radius: 22,
                backgroundImage: (friend.photoUrl != null &&
                        friend.photoUrl!.isNotEmpty)
                    ? NetworkImage(friend.photoUrl!)
                    : null,
                child: (friend.photoUrl == null || friend.photoUrl!.isEmpty)
                    ? Text(friend.displayName.isNotEmpty
                        ? friend.displayName.characters.first.toUpperCase()
                        : '?')
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      friend.displayName,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Level $level · ${friend.totalXp} XP',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'remove') {
                    onRemove();
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem<String>(
                    value: 'remove',
                    child: Text('Freund entfernen'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RankBadge extends StatelessWidget {
  const _RankBadge({required this.rank});

  final int rank;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final (label, color) = switch (rank) {
      1 => ('🥇', theme.colorScheme.primary),
      2 => ('🥈', theme.colorScheme.secondary),
      3 => ('🥉', theme.colorScheme.tertiary),
      _ => ('#$rank', theme.colorScheme.primary),
    };

    final backgroundColor = rank <= 3
        ? color.withOpacity(0.18)
        : theme.colorScheme.surfaceVariant.withOpacity(0.5);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: rank <= 3 ? color : theme.colorScheme.outlineVariant,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: rank <= 3 ? color : theme.textTheme.bodyMedium?.color,
        ),
      ),
    );
  }
}
