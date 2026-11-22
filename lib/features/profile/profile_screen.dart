import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../core/errors/firestore_errors.dart';
import '../../core/firebase/firebase_providers.dart';
import '../../core/models/user_model.dart';
import '../../core/services/haptics.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/theme_mode_controller.dart';
import '../../core/utils/display_name.dart';
import '../../router/app_router.dart';
import '../../shared/widgets/error_state_widget.dart';
import '../../shared/widgets/firestore_permission_widget.dart';
import '../../shared/widgets/gradual_mark.dart';
import '../../shared/widgets/loading_indicator.dart';
import '../../shared/widgets/settings_group.dart';
import '../reminders/reminder_card.dart';
import '../saved/saved_filter.dart';
import '../streak/activity_calendar.dart';
import 'profile_insights.dart';
import 'profile_providers.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileUserProvider);
    final cachedUser = profile.when(
      data: (d) => d,
      loading: () => null,
      error: (_, _) => null,
    );

    return Scaffold(
      backgroundColor: context.colors.background,
      body: profile.when(
        loading: () {
          if (cachedUser != null) return _ProfileBody(user: cachedUser);
          return const LoadingIndicator(label: 'Loading profile...');
        },
        error: (error, _) {
          if (FirestoreErrors.isPermissionDenied(error)) {
            return const FirestorePermissionWidget();
          }
          return ErrorStateWidget(
            message: 'Failed to load profile',
            onRetry: FirestoreErrors.shouldRetry(error) ? () => ref.invalidate(appUserProvider) : null,
          );
        },
        data: (user) {
          if (user == null) {
            return const Center(child: Text('No profile found.'));
          }
          return _ProfileBody(user: user);
        },
      ),
    );
  }
}

class _ProfileBody extends ConsumerWidget {
  const _ProfileBody({required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ProfileStats.from(user, DateTime.now());
    final achievements = achievementsFor(stats);
    final unlocked = achievements.where((a) => a.unlocked).length;

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          _ProfileHeader(user: user, stats: stats),
          const SizedBox(height: 20),
          _StatsGrid(stats: stats),
          const SizedBox(height: 28),
          const SectionLabel('Activity'),
          _Panel(
            child: ActivityCalendar(rawActivityLog: user.rawActivityLog, today: DateTime.now()),
          ),
          const SizedBox(height: 28),
          const SectionLabel('Topics'),
          const _TopicsPanel(),
          const SizedBox(height: 28),
          SectionLabel('Achievements', trailing: '$unlocked of ${achievements.length}'),
          _AchievementsPanel(achievements: achievements),
          const SizedBox(height: 28),
          const SectionLabel('Settings'),
          _SettingsList(user: user),
          const SizedBox(height: 20),
          Center(
            child: Text(
              user.email,
              style: TextStyle(fontSize: 12, color: context.colors.textMuted),
            ),
          ),
        ],
      ),
    );
  }
}

/// White rounded panel used by the profile sections.
class _Panel extends StatelessWidget {
  const _Panel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.border.withValues(alpha: 0.6)),
      ),
      child: child,
    );
  }
}

// ---- Header ----

class _ProfileHeader extends ConsumerWidget {
  const _ProfileHeader({required this.user, required this.stats});

  final AppUser user;
  final ProfileStats stats;

  static const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final account = ref.watch(accountProfileProvider);
    final name = fullNameFor(displayName: account.displayName, email: user.email);
    final level = levelFor(stats.wordsLearned);
    final field = formatCategory(user.fieldOfStudy.replaceAll('_', '-'));
    final since = stats.memberSince;
    final subtitle = since == null
        ? 'Learning $field'
        : 'Learning $field since ${_months[since.month - 1]} ${since.year}';
    final next = level.nextMinWords;

    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: c.border.withValues(alpha: 0.6)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Banner with the avatar overlapping its bottom edge.
          SizedBox(
            height: 150,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  height: 104,
                  decoration: const BoxDecoration(gradient: gradualIconGradient),
                ),
                Positioned(
                  right: -18,
                  top: -10,
                  child: Opacity(
                    opacity: 0.16,
                    child: GradualMark(size: 130, color: Colors.white),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  top: 58,
                  child: Center(child: _Avatar(name: name, photoUrl: account.photoUrl)),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              children: [
                Text(
                  name,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.4),
                ),
                const SizedBox(height: 4),
                Text(subtitle, textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: c.textTertiary)),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                  decoration: BoxDecoration(
                    color: c.brand.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(color: c.brand, borderRadius: BorderRadius.circular(999)),
                            child: Text(
                              'LEVEL ${level.number}',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.6, color: c.onBrand),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(level.name, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: c.textPrimary)),
                          const Spacer(),
                          Text(
                            next == null ? 'Top level' : '${stats.wordsLearned} / $next words',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: c.textTertiary),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _ProgressBar(value: level.progress(stats.wordsLearned)),
                      if (next != null) ...[
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            '${next - stats.wordsLearned} more to ${levelFor(next).name}',
                            style: TextStyle(fontSize: 12, color: c.textTertiary),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.name, this.photoUrl});

  final String name;
  final String? photoUrl;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final initials = Center(
      child: Text(
        initialsFor(name),
        style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900, color: c.onBrand),
      ),
    );
    return Container(
      width: 92,
      height: 92,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: c.surface,
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: c.shadow.withValues(alpha: 0.12), blurRadius: 16, offset: const Offset(0, 6))],
      ),
      child: ClipOval(
        child: DecoratedBox(
          decoration: const BoxDecoration(gradient: gradualIconGradient),
          child: photoUrl == null
              ? initials
              : Image.network(
                  photoUrl!,
                  fit: BoxFit.cover,
                  width: 84,
                  height: 84,
                  errorBuilder: (_, _, _) => initials,
                ),
        ),
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.value, this.color});

  final double value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: value),
        duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : const Duration(milliseconds: 700),
        curve: Curves.easeOutCubic,
        builder: (context, v, _) => LinearProgressIndicator(
          value: v,
          minHeight: 8,
          backgroundColor: c.surfaceSunken,
          color: color ?? c.brand,
        ),
      ),
    );
  }
}

// ---- Stats ----

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.stats});

  final ProfileStats stats;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final accuracy = stats.quizAccuracy;
    String days(int n) => n == 1 ? '1 day' : '$n days';
    final tiles = [
      _StatTile(icon: Icons.menu_book_rounded, color: c.info, value: '${stats.wordsLearned}', label: 'Words learned'),
      _StatTile(
        icon: Icons.local_fire_department_rounded,
        color: c.caution,
        value: days(stats.currentStreak),
        label: 'Current streak',
      ),
      _StatTile(icon: Icons.emoji_events_rounded, color: c.warning, value: days(stats.bestStreak), label: 'Best streak'),
      _StatTile(
        icon: Icons.track_changes_rounded,
        color: c.successBright,
        value: accuracy == null ? '--' : '${(accuracy * 100).round()}%',
        label: stats.quizzesTaken == 1 ? 'Quiz accuracy · 1 quiz' : 'Quiz accuracy · ${stats.quizzesTaken} quizzes',
      ),
    ];
    return Column(
      children: [
        Row(children: [Expanded(child: tiles[0]), const SizedBox(width: 12), Expanded(child: tiles[1])]),
        const SizedBox(height: 12),
        Row(children: [Expanded(child: tiles[2]), const SizedBox(width: 12), Expanded(child: tiles[3])]),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.icon, required this.color, required this.value, required this.label});

  final IconData icon;
  final Color color;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      label: '$label: $value',
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: c.border.withValues(alpha: 0.6)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, size: 18, color: color),
              ),
              const SizedBox(height: 12),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.5),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: c.textTertiary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---- Topics ----

class _TopicsPanel extends ConsumerWidget {
  const _TopicsPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final topics = ref.watch(learnedTopicsProvider);
    return _Panel(
      child: topics.when(
        loading: () => const SizedBox(height: 60, child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
        error: (_, _) => Text("Couldn't load your topics.", style: TextStyle(color: c.textMuted, fontSize: 13)),
        data: (list) {
          if (list.isEmpty) {
            return Text(
              'Read your first words to see your topics here.',
              style: TextStyle(color: c.textMuted, fontSize: 13),
            );
          }
          final max = list.first.$2;
          return Column(
            children: [
              for (var i = 0; i < list.length && i < 6; i++) ...[
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        formatCategory(list[i].$1),
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.textPrimary),
                      ),
                    ),
                    Text(
                      list[i].$2 == 1 ? '1 word' : '${list[i].$2} words',
                      style: TextStyle(fontSize: 12, color: c.textTertiary),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                _ProgressBar(value: list[i].$2 / max, color: c.wordAccent(i)),
                if (i < list.length - 1 && i < 5) const SizedBox(height: 14),
              ],
            ],
          );
        },
      ),
    );
  }
}

// ---- Achievements ----

class _AchievementsPanel extends StatelessWidget {
  const _AchievementsPanel({required this.achievements});

  final List<Achievement> achievements;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: LayoutBuilder(
        builder: (context, constraints) {
          const columns = 4;
          final width = (constraints.maxWidth - 12 * (columns - 1)) / columns;
          return Wrap(
            spacing: 12,
            runSpacing: 16,
            children: [
              for (final a in achievements) SizedBox(width: width, child: _Badge(achievement: a)),
            ],
          );
        },
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.achievement});

  final Achievement achievement;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final a = achievement;
    return Semantics(
      button: true,
      label: '${a.title}, ${a.unlocked ? 'unlocked' : 'locked'}. ${a.description}',
      child: ExcludeSemantics(
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _showDetails(context),
          child: Column(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: a.unlocked ? gradualIconGradient : null,
                  color: a.unlocked ? null : c.surfaceSunken,
                  boxShadow: a.unlocked
                      ? [BoxShadow(color: c.brand.withValues(alpha: 0.25), blurRadius: 10, offset: const Offset(0, 4))]
                      : null,
                ),
                child: Icon(
                  a.unlocked ? a.icon : Icons.lock_rounded,
                  size: a.unlocked ? 24 : 18,
                  color: a.unlocked ? Colors.white : c.textMuted,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                a.title,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  height: 1.2,
                  fontWeight: FontWeight.w600,
                  color: a.unlocked ? c.textPrimary : c.textTertiary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDetails(BuildContext context) {
    final c = context.colors;
    final a = achievement;
    Haptics.selection();
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: a.unlocked ? gradualIconGradient : null,
                  color: a.unlocked ? null : c.surfaceSunken,
                ),
                child: Icon(a.icon, size: 34, color: a.unlocked ? Colors.white : c.textMuted),
              ),
              const SizedBox(height: 14),
              Text(a.title, style: Theme.of(sheet).textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(a.description, style: TextStyle(color: c.textTertiary)),
              const SizedBox(height: 16),
              if (a.unlocked)
                Text('Unlocked', style: TextStyle(fontWeight: FontWeight.w700, color: c.brand))
              else ...[
                _ProgressBar(value: a.progress),
                const SizedBox(height: 8),
                Text('${a.current.clamp(0, a.target)} / ${a.target}', style: TextStyle(fontSize: 12, color: c.textTertiary)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ---- Settings ----

class _SettingsList extends ConsumerWidget {
  const _SettingsList({required this.user});

  final AppUser user;

  static const _fields = [
    ('software_engineering', 'Software Engineering', true),
    ('data_science', 'Data Science', false),
    ('cybersecurity', 'Cybersecurity', false),
    ('product_management', 'Product Management', false),
    ('devops', 'DevOps', false),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final mode = ref.watch(themeModeProvider);
    final fieldLabel = _fields.firstWhere((f) => f.$1 == user.fieldOfStudy, orElse: () => _fields.first).$2;

    return SettingsGroup(
      children: [
        SettingsRow(
          icon: Icons.school_rounded,
          iconColor: c.info,
          title: 'Field of study',
          subtitle: fieldLabel,
          onTap: () => _pickField(context, ref),
        ),
        const ReminderRows(),
        SettingsRow(
          key: const ValueKey('appearance_row'),
          icon: Icons.contrast_rounded,
          iconColor: c.accentPurple,
          title: 'Appearance',
          value: _modeLabel(mode),
          onTap: () => _pickAppearance(context, ref),
        ),
        SettingsRow(
          icon: Icons.logout_rounded,
          iconColor: c.danger,
          title: 'Sign out',
          destructive: true,
          onTap: () => _confirmSignOut(context, ref),
        ),
      ],
    );
  }

  static String _modeLabel(ThemeMode mode) => switch (mode) {
        ThemeMode.system => 'System',
        ThemeMode.light => 'Light',
        ThemeMode.dark => 'Dark',
      };

  void _pickAppearance(BuildContext context, WidgetRef ref) {
    Haptics.selection();
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheet) => Consumer(
        builder: (sheet, ref, _) {
          final current = ref.watch(themeModeProvider);
          return SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Text('Appearance', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                ),
                for (final (mode, icon) in const [
                  (ThemeMode.system, Icons.brightness_auto_rounded),
                  (ThemeMode.light, Icons.light_mode_rounded),
                  (ThemeMode.dark, Icons.dark_mode_rounded),
                ])
                  ListTile(
                    leading: Icon(icon),
                    title: Text(_modeLabel(mode)),
                    trailing: current == mode ? Icon(Icons.check_rounded, color: sheet.colors.brand) : null,
                    onTap: () {
                      Haptics.selection();
                      ref.read(themeModeProvider.notifier).setMode(mode);
                      Navigator.pop(sheet);
                    },
                  ),
                const SizedBox(height: 8),
              ],
            ),
          );
        },
      ),
    );
  }

  void _pickField(BuildContext context, WidgetRef ref) {
    Haptics.selection();
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text('Field of study', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            ),
            for (final (id, label, available) in _fields)
              ListTile(
                enabled: available,
                title: Text(label),
                subtitle: available ? null : const Text('Coming soon'),
                trailing: user.fieldOfStudy == id ? Icon(Icons.check_rounded, color: sheet.colors.brand) : null,
                onTap: () async {
                  Navigator.pop(sheet);
                  if (id == user.fieldOfStudy) return;
                  await ref.read(userRepositoryProvider).createOrUpdateUser(user.copyWith(fieldOfStudy: id));
                  ref.invalidate(appUserProvider);
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _confirmSignOut(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Sign out?', style: TextStyle(fontWeight: FontWeight.w800)),
        content: Text('You will be returned to the login screen.', style: TextStyle(color: context.colors.textTertiary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: context.colors.textTertiary)),
          ),
          TextButton(
            onPressed: () async {
              final nav = Navigator.of(context);
              Navigator.pop(ctx);
              if (!kIsWeb) {
                await GoogleSignIn().signOut();
              }
              await ref.read(firebaseAuthProvider).signOut();
              nav.pushNamedAndRemoveUntil(AppRoutes.root, (_) => false);
            },
            child: Text('Sign Out', style: TextStyle(color: context.colors.danger, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}
