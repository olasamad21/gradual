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
/// Firebase restores the cached session automatically on app restart —
/// this stream will emit null briefly, then the restored User once ready.
final authStateChangesProvider = StreamProvider<User?>((ref) {
  final auth = ref.watch(firebaseAuthProvider);
  return auth.authStateChanges();
});

/// The current [AppUser] document for the signed-in Firebase user.
///
/// FIXED: Now listens to authStateChanges instead of reading currentUser
/// directly. This prevents the race condition where currentUser is null
/// for ~500ms on cold start while Firebase restores the cached token.
final appUserProvider = StreamProvider<AppUser?>((ref) {
  final repo = ref.watch(userRepositoryProvider);

  // Watch the auth stream — when Firebase restores the session after
  // a cold start, this automatically re-fires with the correct user.
  final authAsync = ref.watch(authStateChangesProvider);

  return authAsync.when(
    // Emit null while auth resolves so dependents stay in data state (no flicker).
    loading: () => Stream.value(null),

    error: (_, __) => Stream.value(null),

    data: (user) {
      if (user == null) return Stream.value(null);
      return repo.userStream(user.uid);
    },
  );
});