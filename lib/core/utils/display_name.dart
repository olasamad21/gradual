import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../firebase/firebase_providers.dart';

/// Name and photo from the signed-in Google account, when available.
typedef AccountProfile = ({String? displayName, String? photoUrl});

/// Reads the Firebase user's Google profile. Returns empty values when
/// Firebase is unavailable (for example in widget tests).
final accountProfileProvider = Provider<AccountProfile>((ref) {
  // Touching FirebaseAuth before Firebase.initializeApp leaves work pending,
  // so check first.
  if (Firebase.apps.isEmpty) return (displayName: null, photoUrl: null);
  try {
    final user = ref.watch(firebaseAuthProvider).currentUser;
    return (displayName: user?.displayName, photoUrl: user?.photoURL);
  } catch (_) {
    return (displayName: null, photoUrl: null);
  }
});

/// Full name for headings: the account name, or a tidied email prefix.
String fullNameFor({String? displayName, required String email}) {
  final name = displayName?.trim() ?? '';
  if (name.isNotEmpty) return name;
  return _nameFromEmail(email);
}

/// First name for greetings: the first word of the account name, or a
/// tidied email prefix.
String firstNameFor({String? displayName, required String email}) {
  final name = displayName?.trim() ?? '';
  if (name.isNotEmpty) return name.split(RegExp(r'\s+')).first;
  return _nameFromEmail(email).split(' ').first;
}

/// Up to two initials for an avatar.
String initialsFor(String fullName) {
  final parts = fullName.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  final first = parts.first[0];
  final last = parts.length > 1 ? parts.last[0] : '';
  return (first + last).toUpperCase();
}

/// "jane.doe_99@x.com" becomes "Jane Doe".
String _nameFromEmail(String email) {
  final prefix = email.split('@').first;
  final words = prefix
      .replaceAll(RegExp(r'\d+'), ' ')
      .split(RegExp(r'[._\-+\s]+'))
      .where((w) => w.isNotEmpty)
      .map((w) => '${w[0].toUpperCase()}${w.substring(1)}')
      .toList();
  return words.isEmpty ? 'there' : words.join(' ');
}
