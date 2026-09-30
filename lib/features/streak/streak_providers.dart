import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/firebase/firebase_providers.dart';

/// Live weekly streak (0 if the user missed this week's Saturday deadline).
final streakCountProvider = Provider<AsyncValue<int>>((ref) {
  final appUserAsync = ref.watch(appUserProvider);
  return appUserAsync.whenData((user) => user?.liveStreak ?? 0);
});

final statsResetProvider = FutureProvider<void>((ref) async {
  final userAsync = ref.watch(appUserProvider);
  if (userAsync.isLoading) return; // Wait for initial load
  final user = userAsync.whenOrNull(data: (d) => d);
  if (user == null) return;
  
  final repo = ref.read(userRepositoryProvider);
  await repo.resetStatsIfNeeded(user.uid);
});

