import 'package:flutter/foundation.dart' show kIsWeb;
import '../../core/theme/streak_colors.dart';
import '../../shared/widgets/dot_pattern.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/theme_mode_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../core/errors/firestore_errors.dart';
import '../../core/firebase/firebase_providers.dart';
import '../../router/app_router.dart';
import '../../core/models/user_model.dart';
import '../../shared/widgets/loading_indicator.dart';
import '../../shared/widgets/error_state_widget.dart';
import '../../shared/widgets/firestore_permission_widget.dart';
import '../streak/streak_heatmap_widget.dart';
import 'profile_providers.dart';
import 'profile_quiz_stats.dart';

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
            onRetry: FirestoreErrors.shouldRetry(error)
                ? () => ref.invalidate(appUserProvider)
                : null,
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

  String _totalQuizzesDone(AppUser u) => totalQuizzesDone(u);

  String _allTimeCorrectPercent(AppUser u) => allTimeCorrectPercent(u);

  void _confirmSignOut(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Sign out?', style: TextStyle(fontWeight: FontWeight.w800)),
        content: Text('You will be returned to the login screen.',
            style: TextStyle(color: context.colors.textTertiary)),
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
            child: Text('Sign Out',
                style: TextStyle(color: context.colors.danger, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final initials = user.email.isNotEmpty ? user.email[0].toUpperCase() : '?';
    final username = user.email.split('@').first;

    return CustomPaint(
      painter: DotPatternPainter(color: context.colors.dotPattern),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.arrow_back_rounded, color: context.colors.textPrimary),
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                  ),
                  const Spacer(),
                  Text('Profile',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: context.colors.textPrimary)),
                  const Spacer(),
                  const SizedBox(width: 40),
                ],
              ),
              const SizedBox(height: 24),

              // Avatar card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: context.colors.surface,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [BoxShadow(color: context.colors.shadow.withValues(alpha: 0.05), blurRadius: 20, offset: const Offset(0, 6))],
                ),
                child: Column(
                  children: [
                    Container(
                      width: 80, height: 80,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [context.colors.brand, context.colors.brandStrong],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: context.colors.brand.withValues(alpha: 0.3), blurRadius: 16, offset: const Offset(0, 6))],
                      ),
                      child: Center(
                        child: Text(initials,
                            style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: context.colors.onBrand)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(username,
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: context.colors.textPrimary, letterSpacing: -0.5)),
                    const SizedBox(height: 4),
                    Text(user.email, style: TextStyle(fontSize: 13, color: context.colors.textMuted)),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Stat cards using liveStreak
              Row(
                children: [
                  _StatCard(
                    icon: Icons.local_fire_department_rounded,
                    iconColor: context.colors.caution,
                    label: 'Current Streak',
                    value: user.liveStreak == 1
                        ? '1 day'
                        : '${user.liveStreak} days',
                  ),
                  const SizedBox(width: 12),
                  _StatCard(
                    icon: Icons.quiz_rounded,
                    iconColor: context.colors.successBright,
                    label: 'Quizzes Done',
                    value: _totalQuizzesDone(user),
                  ),
                  const SizedBox(width: 12),
                  _StatCard(
                    icon: Icons.percent_rounded,
                    iconColor: context.colors.warning,
                    label: 'Correct Rate',
                    value: _allTimeCorrectPercent(user),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Heatmap card passing liveStreak
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: context.colors.surface,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: context.colors.shadow.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 4))],
                ),
                child: StreakHeatmapWidget(
                  rawActivityLog: user.rawActivityLog,
                  liveStreak: user.liveStreak,
                  today: DateTime.now(),
                ),
              ),
              const SizedBox(height: 16),

              _FieldOfStudyCard(user: user),
              const SizedBox(height: 16),
              const _AppearanceCard(),
              const SizedBox(height: 16),
              _QuizHistoryCard(user: user),
              const SizedBox(height: 16),

              // Sign out
              SizedBox(
                width: double.infinity, height: 52,
                child: OutlinedButton.icon(
                  onPressed: () => _confirmSignOut(context, ref),
                  icon: Icon(Icons.logout_rounded, color: context.colors.danger, size: 20),
                  label: Text('Sign Out',
                      style: TextStyle(color: context.colors.danger, fontWeight: FontWeight.w700, fontSize: 15)),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: context.colors.dangerBorder, width: 2),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---- Stat Card ----

class _StatCard extends StatelessWidget {
  const _StatCard({required this.icon, required this.iconColor, required this.label, required this.value});
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: context.colors.shadow.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: Column(
          children: [
            Icon(icon, color: iconColor, size: 24),
            const SizedBox(height: 8),
            Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: context.colors.textPrimary)),
            const SizedBox(height: 2),
            Text(label,
                style: TextStyle(fontSize: 10, color: context.colors.textMuted, fontWeight: FontWeight.w500),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

// ---- Field of Study Card ----

class _FieldOfStudyCard extends ConsumerStatefulWidget {
  const _FieldOfStudyCard({required this.user});
  final AppUser user;

  @override
  ConsumerState<_FieldOfStudyCard> createState() => _FieldOfStudyCardState();
}

class _FieldOfStudyCardState extends ConsumerState<_FieldOfStudyCard> {
  bool _isEditing = false;
  bool _isSaving = false;
  String? _selected;

  static const _fields = [
    'software_engineering', 'data_science', 'cybersecurity', 'product_management', 'devops',
  ];
  static const _labels = {
    'software_engineering': 'Software Engineering',
    'data_science': 'Data Science',
    'cybersecurity': 'Cybersecurity',
    'product_management': 'Product Management',
    'devops': 'DevOps',
  };

  @override
  void initState() { super.initState(); _selected = widget.user.fieldOfStudy; }

  Future<void> _save() async {
    if (_selected == null) return;
    setState(() => _isSaving = true);
    try {
      final repo = ref.read(userRepositoryProvider);
      await repo.createOrUpdateUser(widget.user.copyWith(fieldOfStudy: _selected));
      ref.invalidate(appUserProvider);
      setState(() => _isEditing = false);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.colors.surface, borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: context.colors.shadow.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(color: context.colors.info.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                child: Icon(Icons.school_rounded, color: context.colors.info, size: 20),
              ),
              const SizedBox(width: 12),
              Text('Field of Study',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: context.colors.textPrimary)),
              const Spacer(),
              if (!_isEditing)
                GestureDetector(
                  onTap: () => setState(() => _isEditing = true),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: context.colors.brand.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
                    child: Text('Edit', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: context.colors.brand)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          if (!_isEditing)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                  color: context.colors.surfaceMuted,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: context.colors.border)),
              child: Text(_labels[widget.user.fieldOfStudy] ?? widget.user.fieldOfStudy,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: context.colors.textBody)),
            )
          else ...[
            ..._fields.map((field) {
              final isSelected = _selected == field;
              return GestureDetector(
                onTap: () => setState(() => _selected = field),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: isSelected ? context.colors.brand.withValues(alpha: 0.06) : context.colors.surfaceMuted,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: isSelected ? context.colors.brand : context.colors.border,
                        width: isSelected ? 2 : 1),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(_labels[field] ?? field,
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                color: isSelected ? context.colors.brand : context.colors.textBody)),
                      ),
                      if (isSelected) Icon(Icons.check_circle_rounded, color: context.colors.brand, size: 18),
                    ],
                  ),
                ),
              );
            }),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isSaving ? null : () => setState(() { _isEditing = false; _selected = widget.user.fieldOfStudy; }),
                    style: OutlinedButton.styleFrom(
                        side: BorderSide(color: context.colors.border),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                    child: Text('Cancel', style: TextStyle(color: context.colors.textTertiary)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _save,
                    style: ElevatedButton.styleFrom(
                        backgroundColor: context.colors.brand,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 0),
                    child: _isSaving
                        ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: context.colors.onBrand, strokeWidth: 2))
                        : Text('Save', style: TextStyle(color: context.colors.onBrand, fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ---- Quiz History Card ----

class _QuizHistoryCard extends StatelessWidget {
  const _QuizHistoryCard({required this.user});
  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final entries = sortedQuizHistoryEntries(user);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.colors.surface, borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: context.colors.shadow.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(color: context.colors.accentPurple.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                child: Icon(Icons.history_rounded, color: context.colors.accentPurple, size: 20),
              ),
              const SizedBox(width: 12),
              Text('Quiz History',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: context.colors.textPrimary)),
              const Spacer(),
              Text('${entries.length} weeks',
                  style: TextStyle(fontSize: 12, color: context.colors.textMuted)),
            ],
          ),
          const SizedBox(height: 14),
          if (entries.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Column(
                  children: [
                    Icon(Icons.quiz_outlined, size: 36, color: context.colors.borderStrong),
                    const SizedBox(height: 8),
                    Text('No quiz sessions yet.',
                        style: TextStyle(color: context.colors.textMuted, fontSize: 13)),
                  ],
                ),
              ),
            )
          else
            ...entries.take(10).map((e) => _HistoryRow(dateId: e.key, entry: e.value)),
          if (entries.length > 10)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Center(
                child: Text('+ ${entries.length - 10} more',
                    style: TextStyle(fontSize: 12, color: context.colors.textMuted)),
              ),
            ),
        ],
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.dateId, required this.entry});
  final String dateId;
  final ActivityLogEntry entry;

  Widget _badge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(5)),
      child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tier = entry.isWeeklyQuiz ? entry.tier : WeeklyScoreTier.legacy;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: context.colors.surfaceMuted,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.colors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(dateId,
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: context.colors.textBody)),
                const SizedBox(height: 4),
                _badge(tier.label, StreakColors.tierColor(tier, context.colors)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                children: [
                  Icon(Icons.star_rounded, color: context.colors.warning, size: 14),
                  const SizedBox(width: 3),
                  Text('${entry.score}/${entry.totalQuestions}',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: context.colors.textPrimary)),
                ],
              ),
              Text(
                '${entry.totalQuestions == 0 ? 0 : (entry.score / entry.totalQuestions * 100).round()}%',
                style: TextStyle(fontSize: 11, color: context.colors.textMuted),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---- Appearance Card ----

class _AppearanceCard extends ConsumerWidget {
  const _AppearanceCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: context.colors.shadow.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: context.colors.accentPurple.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.contrast_rounded, color: context.colors.accentPurple, size: 20),
              ),
              const SizedBox(width: 12),
              Text('Appearance',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: context.colors.textPrimary)),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<ThemeMode>(
              key: const ValueKey('appearance_selector'),
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: ThemeMode.system, label: Text('System'), icon: Icon(Icons.brightness_auto_rounded, size: 18)),
                ButtonSegment(value: ThemeMode.light, label: Text('Light'), icon: Icon(Icons.light_mode_rounded, size: 18)),
                ButtonSegment(value: ThemeMode.dark, label: Text('Dark'), icon: Icon(Icons.dark_mode_rounded, size: 18)),
              ],
              selected: {mode},
              onSelectionChanged: (s) => ref.read(themeModeProvider.notifier).setMode(s.first),
              style: SegmentedButton.styleFrom(
                foregroundColor: context.colors.textSecondary,
                selectedForegroundColor: context.colors.brand,
                selectedBackgroundColor: context.colors.brand.withValues(alpha: 0.12),
                side: BorderSide(color: context.colors.border),
                textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
