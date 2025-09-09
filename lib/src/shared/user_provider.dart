import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final userDocProvider = StreamProvider<DocumentSnapshot<Map<String, dynamic>>?>((ref) {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return const Stream<DocumentSnapshot<Map<String, dynamic>>?>.empty();
  final doc = FirebaseFirestore.instance.collection('users').doc(user.uid);
  return doc.snapshots();
});
