import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/widgets/error_state_widget.dart';
import '../../shared/widgets/loading_indicator.dart';
import '../streak/streak_heatmap_widget.dart';
import 'profile_providers.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileUserProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
      ),
      body: profile.when(
        data: (user) {
          if (user == null) {
            return const Center(
              child: Text('No profile found.'),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.email,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  'Field: ${user.fieldOfStudy}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                Text(
                  'Current Streak: ${user.currentStreak} days',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Year Heatmap',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                StreakHeatmapWidget(activityLog: user.activityLog),
              ],
            ),
          );
        },
        loading: () => const LoadingIndicator(label: 'Loading profile...'),
        error: (error, _) => ErrorStateWidget(
          message: 'Failed to load profile',
          onRetry: () {
            // Simple refresh by invalidating provider.
            ref.invalidate(profileUserProvider);
          },
        ),
      ),
    );
  }
}

