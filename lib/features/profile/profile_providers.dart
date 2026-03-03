import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/firebase/firebase_providers.dart';
import '../../core/models/user_model.dart';

/// Exposes the current [AppUser] along with loading/error state.
final profileUserProvider = Provider<AsyncValue<AppUser?>>((ref) {
  return ref.watch(appUserProvider);
});