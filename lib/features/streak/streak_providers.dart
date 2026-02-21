import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/firebase/firebase_providers.dart';

/// Simple derived provider exposing the current streak count.
final streakCountProvider = Provider<AsyncValue<int>>((ref) {
  final appUserAsync = ref.watch(appUserProvider);
  return appUserAsync.whenData((user) => user?.currentStreak ?? 0);
});

