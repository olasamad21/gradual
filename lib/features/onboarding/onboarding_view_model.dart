// lib/features/onboarding/onboarding_view_model.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../core/firebase/firebase_providers.dart';
import '../../core/models/user_model.dart';
import '../../core/repositories/user_repository.dart';

final onboardingControllerProvider =
    AsyncNotifierProvider<OnboardingController, void>(
  OnboardingController.new,
);

class OnboardingController extends AsyncNotifier<void> {
  late final FirebaseAuth _auth;
  late final UserRepository _userRepository;
  late final GoogleSignIn? _googleSignIn = kIsWeb
      ? null
      : GoogleSignIn(
          scopes: <String>['email'],
        );

  @override
  Future<void> build() async {
    _auth = ref.read(firebaseAuthProvider);
    _userRepository = ref.read(userRepositoryProvider);
  }

  Future<User?> signInWithGoogle() async {
    try {
      state = const AsyncLoading();

      final UserCredential userCred;

      if (kIsWeb) {
        // WEB: Call popup directly. No awaits precede this call to avoid popup blockers.
        final provider = GoogleAuthProvider()..addScope('email');
        userCred = await _auth.signInWithPopup(provider);
      } else {
        // MOBILE: Existing google_sign_in flow.
        final googleUser = await _googleSignIn!.signIn();
        if (googleUser == null) {
          state = const AsyncData(null);
          return null;
        }

        final googleAuth = await googleUser.authentication;
        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );

        userCred = await _auth.signInWithCredential(credential);
      }

      state = const AsyncData(null);
      return userCred.user;
    } catch (_) {
      // Return to a clean state so the user can try again (e.g., if popup closed)
      state = const AsyncData(null);
      rethrow;
    }
  }

  Future<void> completeProfile({
    required String fieldOfStudy,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('No signed-in user');
    }

    final appUser = AppUser(
      uid: user.uid,
      email: user.email ?? '',
      fieldOfStudy: fieldOfStudy,
      currentStreak: 0,
      lastActivityDate: null,
      activityLog: const {},
    );

    await _userRepository.createOrUpdateUser(appUser);
  }
}