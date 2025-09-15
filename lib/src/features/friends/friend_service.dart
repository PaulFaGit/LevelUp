import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FriendServiceException implements Exception {
  FriendServiceException(this.message);
  final String message;

  @override
  String toString() => message;
}

class FriendService {
  FriendService._();

  static FirebaseFirestore get _db => FirebaseFirestore.instance;
  static FirebaseAuth get _auth => FirebaseAuth.instance;

  static String? get currentUserId => _auth.currentUser?.uid;

  static String pairKey(String a, String b) {
    if (a == b) return '${a}_self';
    final values = [a, b]..sort();
    return '${values[0]}_${values[1]}';
  }

  static Future<void> sendFriendRequest(String targetUserId) async {
    final currentUid = currentUserId;
    if (currentUid == null) {
      throw FriendServiceException('Bitte melde dich zunächst an.');
    }
    if (currentUid == targetUserId) {
      throw FriendServiceException('Du kannst dich nicht selbst hinzufügen.');
    }

    final pair = pairKey(currentUid, targetUserId);

    final currentFriendDoc = await _db
        .collection('users')
        .doc(currentUid)
        .collection('friends')
        .doc(targetUserId)
        .get();
    if (currentFriendDoc.exists) {
      throw FriendServiceException('Ihr seid bereits befreundet.');
    }

    final existingPendingQuery = await _db
        .collection('friend_requests')
        .where('pairKey', isEqualTo: pair)
        .where('status', isEqualTo: 'pending')
        .limit(1)
        .get();

    if (existingPendingQuery.docs.isNotEmpty) {
      final pendingDoc = existingPendingQuery.docs.first;
      final data = pendingDoc.data();
      final fromUserId = (data['fromUserId'] ?? '') as String;
      final toUserId = (data['toUserId'] ?? '') as String;

      if (fromUserId == currentUid) {
        throw FriendServiceException('Anfrage wurde bereits gesendet.');
      }

      if (toUserId == currentUid) {
        await acceptFriendRequest(pendingDoc.id);
        return;
      }
    }

    final now = FieldValue.serverTimestamp();
    await _db.collection('friend_requests').add({
      'fromUserId': currentUid,
      'toUserId': targetUserId,
      'pairKey': pair,
      'status': 'pending',
      'createdAt': now,
      'updatedAt': now,
    });
  }

  static Future<void> acceptFriendRequest(String requestId) async {
    final currentUid = currentUserId;
    if (currentUid == null) {
      throw FriendServiceException('Bitte melde dich zunächst an.');
    }

    final requestRef = _db.collection('friend_requests').doc(requestId);

    await _db.runTransaction((transaction) async {
      final snapshot = await transaction.get(requestRef);
      if (!snapshot.exists) {
        throw FriendServiceException('Die Anfrage existiert nicht mehr.');
      }
      final data = snapshot.data()!;
      final status = (data['status'] ?? 'pending') as String;
      final fromUserId = (data['fromUserId'] ?? '') as String;
      final toUserId = (data['toUserId'] ?? '') as String;

      if (toUserId != currentUid) {
        throw FriendServiceException('Diese Anfrage gehört nicht zu dir.');
      }
      if (status != 'pending') {
        throw FriendServiceException('Die Anfrage wurde bereits bearbeitet.');
      }

      final serverTimestamp = FieldValue.serverTimestamp();

      transaction.update(requestRef, {
        'status': 'accepted',
        'updatedAt': serverTimestamp,
        'respondedAt': serverTimestamp,
      });

      final currentFriendRef = _db
          .collection('users')
          .doc(currentUid)
          .collection('friends')
          .doc(fromUserId);
      final otherFriendRef = _db
          .collection('users')
          .doc(fromUserId)
          .collection('friends')
          .doc(currentUid);

      transaction.set(currentFriendRef, {
        'friendId': fromUserId,
        'createdAt': serverTimestamp,
      });
      transaction.set(otherFriendRef, {
        'friendId': currentUid,
        'createdAt': serverTimestamp,
      });
    });
  }

  static Future<void> declineFriendRequest(String requestId) async {
    final currentUid = currentUserId;
    if (currentUid == null) {
      throw FriendServiceException('Bitte melde dich zunächst an.');
    }

    final requestRef = _db.collection('friend_requests').doc(requestId);

    await _db.runTransaction((transaction) async {
      final snapshot = await transaction.get(requestRef);
      if (!snapshot.exists) {
        return;
      }
      final data = snapshot.data()!;
      final status = (data['status'] ?? 'pending') as String;
      final toUserId = (data['toUserId'] ?? '') as String;

      if (toUserId != currentUid) {
        throw FriendServiceException('Du kannst diese Anfrage nicht ablehnen.');
      }
      if (status != 'pending') {
        return;
      }

      final serverTimestamp = FieldValue.serverTimestamp();
      transaction.update(requestRef, {
        'status': 'declined',
        'updatedAt': serverTimestamp,
        'respondedAt': serverTimestamp,
      });
    });
  }

  static Future<void> cancelFriendRequest(String requestId) async {
    final currentUid = currentUserId;
    if (currentUid == null) {
      throw FriendServiceException('Bitte melde dich zunächst an.');
    }

    final requestRef = _db.collection('friend_requests').doc(requestId);

    await _db.runTransaction((transaction) async {
      final snapshot = await transaction.get(requestRef);
      if (!snapshot.exists) {
        return;
      }
      final data = snapshot.data()!;
      final status = (data['status'] ?? 'pending') as String;
      final fromUserId = (data['fromUserId'] ?? '') as String;

      if (fromUserId != currentUid) {
        throw FriendServiceException('Du kannst diese Anfrage nicht abbrechen.');
      }
      if (status != 'pending') {
        return;
      }

      final serverTimestamp = FieldValue.serverTimestamp();
      transaction.update(requestRef, {
        'status': 'cancelled',
        'updatedAt': serverTimestamp,
        'respondedAt': serverTimestamp,
      });
    });
  }

  static Future<void> removeFriend(String friendUserId) async {
    final currentUid = currentUserId;
    if (currentUid == null) {
      throw FriendServiceException('Bitte melde dich zunächst an.');
    }

    final batch = _db.batch();
    final currentRef = _db
        .collection('users')
        .doc(currentUid)
        .collection('friends')
        .doc(friendUserId);
    final otherRef = _db
        .collection('users')
        .doc(friendUserId)
        .collection('friends')
        .doc(currentUid);

    batch.delete(currentRef);
    batch.delete(otherRef);
    await batch.commit();
  }

  static Stream<List<FriendUser>> friendsStream(String userId) {
    final collection =
        _db.collection('users').doc(userId).collection('friends');
    return collection.snapshots().asyncMap((snapshot) async {
      if (snapshot.docs.isEmpty) {
        return <FriendUser>[];
      }

      final ids = snapshot.docs.map((doc) => doc.id).toList();
      final userDocs = await _fetchUsersByIds(ids);
      final friendEntries = <FriendUser>[];

      for (final doc in userDocs) {
        final data = doc.data();
        if (data == null) continue;
        friendEntries.add(
          FriendUser(
            userId: doc.id,
            displayName: (data['displayName'] ?? 'Profil').toString(),
            photoUrl: (data['photoURL'] ?? data['photoUrl'] ?? '') as String?,
            totalXp: (data['totalXP'] ?? 0) as int,
          ),
        );
      }

      friendEntries.sort((a, b) => b.totalXp.compareTo(a.totalXp));
      return friendEntries;
    });
  }

  static Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
      _fetchUsersByIds(List<String> ids) async {
    final chunks = <List<String>>[];
    const chunkSize = 10;
    for (var i = 0; i < ids.length; i += chunkSize) {
      chunks.add(ids.sublist(i, min(i + chunkSize, ids.length)));
    }

    final futures = chunks.map((chunk) {
      return _db
          .collection('users')
          .where(FieldPath.documentId, whereIn: chunk)
          .get();
    });

    final results = await Future.wait(futures);
    return results.expand((snapshot) => snapshot.docs).toList();
  }

  static Future<List<FriendSearchResult>> searchUsers(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      return const [];
    }

    final currentUid = currentUserId;

    final snapshot = await _db
        .collection('users')
        .orderBy('displayName')
        .startAt([trimmed])
        .endAt(['$trimmed\uf8ff'])
        .limit(10)
        .get();

    final results = <FriendSearchResult>[];
    for (final doc in snapshot.docs) {
      if (doc.id == currentUid) continue;
      final data = doc.data();
      results.add(
        FriendSearchResult(
          userId: doc.id,
          displayName: (data['displayName'] ?? 'Profil').toString(),
          photoUrl: (data['photoURL'] ?? data['photoUrl'] ?? '') as String?,
          totalXp: (data['totalXP'] ?? 0) as int,
        ),
      );
    }
    return results;
  }
}

class FriendUser {
  const FriendUser({
    required this.userId,
    required this.displayName,
    required this.photoUrl,
    required this.totalXp,
  });

  final String userId;
  final String displayName;
  final String? photoUrl;
  final int totalXp;
}

class FriendSearchResult {
  const FriendSearchResult({
    required this.userId,
    required this.displayName,
    required this.photoUrl,
    required this.totalXp,
  });

  final String userId;
  final String displayName;
  final String? photoUrl;
  final int totalXp;
}
