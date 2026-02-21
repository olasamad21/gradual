import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/user_model.dart';
import '../repositories/content_repository.dart';
import '../repositories/user_repository.dart';

final firebaseAuthProvider = Provider<FirebaseAuth>((ref) {
  return FirebaseAuth.instance;
});

final firestoreProvider = Provider<FirebaseFirestore>((ref) {
  return FirebaseFirestore.instance;
});

final firebaseMessagingProvider = Provider<FirebaseMessaging>((ref) {
  return FirebaseMessaging.instance;
});

final userRepositoryProvider = Provider<UserRepository>((ref) {
  final firestore = ref.watch(firestoreProvider);
  return UserRepository(firestore);
});

final contentRepositoryProvider = Provider<ContentRepository>((ref) {
  final firestore = ref.watch(firestoreProvider);
  return ContentRepository(firestore);
});

/// Auth state as a stream of Firebase [User?].
final authStateChangesProvider = StreamProvider<User?>((ref) {
  final auth = ref.watch(firebaseAuthProvider);
  return auth.authStateChanges();
});

/// The current [AppUser] document for the signed-in Firebase user.
final appUserProvider = StreamProvider<AppUser?>((ref) {
  final auth = ref.watch(firebaseAuthProvider);
  final repo = ref.watch(userRepositoryProvider);

  final user = auth.currentUser;
  if (user == null) {
    return const Stream<AppUser?>.empty();
  }

  return repo.userStream(user.uid);
});

