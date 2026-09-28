import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/firestore_errors.dart';
import '../../core/firebase/firebase_providers.dart';
import '../../core/models/user_model.dart';
import '../../shared/widgets/loading_indicator.dart';
import '../../shared/widgets/error_state_widget.dart';
import '../../shared/widgets/firestore_permission_widget.dart';
import '../daily_word/daily_word_screen.dart';
import '../streak/streak_heatmap_widget.dart';
import 'profile_providers.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileUserProvider);
    final cachedUser = profile.when(
      data: (d) => d,
      loading: () => null,
      error: (_, __) => null,
    );

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
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

  String _totalQuizzesDone(AppUser u) {
    final total =
        u.activityLog.values.where((e) => e.isWeeklyQuiz).length;
    return '$total';
  }

  String _allTimeCorrectPercent(AppUser u) {
    int totalCorrect = 0;
    int totalQuestions = 0;
    for (final entry in u.activityLog.values) {
      if (!entry.isWeeklyQuiz) continue;
      totalCorrect += entry.score;
      totalQuestions += entry.totalQuestions;
    }
    if (totalQuestions == 0) return '--';
    return '${(totalCorrect / totalQuestions * 100).round()}%';
  }

  void _confirmSignOut(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Sign out?', style: TextStyle(fontWeight: FontWeight.w800)),
        content: const Text('You will be returned to the login screen.',
            style: TextStyle(color: Color(0xFF6B7280))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF6B7280))),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(firebaseAuthProvider).signOut();
            },
            child: const Text('Sign Out',
                style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.w700)),
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
      painter: DotPatternPainter(),
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
                    icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF1F2937)),
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                  ),
                  const Spacer(),
                  const Text('Profile',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF1F2937))),
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
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 6))],
                ),
                child: Column(
                  children: [
                    Container(
                      width: 80, height: 80,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF388E3C), Color(0xFF1B5E20)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: const Color(0xFF388E3C).withOpacity(0.3), blurRadius: 16, offset: const Offset(0, 6))],
                      ),
                      child: Center(
                        child: Text(initials,
                            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Colors.white)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(username,
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF1F2937), letterSpacing: -0.5)),
                    const SizedBox(height: 4),
                    Text(user.email, style: const TextStyle(fontSize: 13, color: Color(0xFF9CA3AF))),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Stat cards using liveStreak
              Row(
                children: [
                  _StatCard(
                    icon: Icons.local_fire_department_rounded,
                    iconColor: const Color(0xFFF97316),
                    label: 'Current Streak',
                    value: user.liveStreak == 1
                        ? '1 wk'
                        : '${user.liveStreak} wks',
                  ),
                  const SizedBox(width: 12),
                  _StatCard(
                    icon: Icons.quiz_rounded,
                    iconColor: const Color(0xFF22C55E),
                    label: 'Quizzes Done',
                    value: _totalQuizzesDone(user),
                  ),
                  const SizedBox(width: 12),
                  _StatCard(
                    icon: Icons.percent_rounded,
                    iconColor: const Color(0xFFF59E0B),
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
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 4))],
                ),
                child: StreakHeatmapWidget(
                  activityLog: user.activityLog,
                  liveStreak: user.liveStreak,
                ),
              ),
              const SizedBox(height: 16),

              _FieldOfStudyCard(user: user),
              const SizedBox(height: 16),
              _QuizHistoryCard(user: user),
              const SizedBox(height: 16),

              // Sign out
              SizedBox(
                width: double.infinity, height: 52,
                child: OutlinedButton.icon(
                  onPressed: () => _confirmSignOut(context, ref),
                  icon: const Icon(Icons.logout_rounded, color: Color(0xFFEF4444), size: 20),
                  label: const Text('Sign Out',
                      style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.w700, fontSize: 15)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFFECACA), width: 2),
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

// ── Stat Card ────────────────────────────────────────────────

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
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: Column(
          children: [
            Icon(icon, color: iconColor, size: 24),
            const SizedBox(height: 8),
            Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF1F2937))),
            const SizedBox(height: 2),
            Text(label,
                style: const TextStyle(fontSize: 10, color: Color(0xFF9CA3AF), fontWeight: FontWeight.w500),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

// ── Field of Study Card ──────────────────────────────────────

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
        color: Colors.white, borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(color: const Color(0xFF3B82F6).withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.school_rounded, color: Color(0xFF3B82F6), size: 20),
              ),
              const SizedBox(width: 12),
              const Text('Field of Study',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF1F2937))),
              const Spacer(),
              if (!_isEditing)
                GestureDetector(
                  onTap: () => setState(() => _isEditing = true),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: const Color(0xFF388E3C).withOpacity(0.08), borderRadius: BorderRadius.circular(8)),
                    child: const Text('Edit', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF388E3C))),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          if (!_isEditing)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                  color: const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE5E7EB))),
              child: Text(_labels[widget.user.fieldOfStudy] ?? widget.user.fieldOfStudy,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
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
                    color: isSelected ? const Color(0xFF388E3C).withOpacity(0.06) : const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: isSelected ? const Color(0xFF388E3C) : const Color(0xFFE5E7EB),
                        width: isSelected ? 2 : 1),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(_labels[field] ?? field,
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                color: isSelected ? const Color(0xFF388E3C) : const Color(0xFF374151))),
                      ),
                      if (isSelected) const Icon(Icons.check_circle_rounded, color: Color(0xFF388E3C), size: 18),
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
                        side: const BorderSide(color: Color(0xFFE5E7EB)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                    child: const Text('Cancel', style: TextStyle(color: Color(0xFF6B7280))),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _save,
                    style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF388E3C),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 0),
                    child: _isSaving
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('Save', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
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

// ── Quiz History Card ────────────────────────────────────────

class _QuizHistoryCard extends StatelessWidget {
  const _QuizHistoryCard({required this.user});
  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final entries = user.activityLog.entries
        .where((e) => e.value.isWeeklyQuiz)
        .toList()
      ..sort((a, b) => b.key.compareTo(a.key));

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(color: const Color(0xFF8B5CF6).withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.history_rounded, color: Color(0xFF8B5CF6), size: 20),
              ),
              const SizedBox(width: 12),
              const Text('Quiz History',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF1F2937))),
              const Spacer(),
              Text('${entries.where((e) => e.value.isWeeklyQuiz).length} weeks',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
            ],
          ),
          const SizedBox(height: 14),
          if (entries.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Column(
                  children: [
                    Icon(Icons.quiz_outlined, size: 36, color: Colors.grey.shade300),
                    const SizedBox(height: 8),
                    Text('No quiz sessions yet.',
                        style: TextStyle(color: Colors.grey.shade400, fontSize: 13)),
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
                    style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
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
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(5)),
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
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(dateId,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
                const SizedBox(height: 4),
                _badge(tier.label, tier.color),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                children: [
                  const Icon(Icons.star_rounded, color: Color(0xFFF59E0B), size: 14),
                  const SizedBox(width: 3),
                  Text('${entry.score}/${entry.totalQuestions}',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF1F2937))),
                ],
              ),
              Text(
                '${entry.totalQuestions == 0 ? 0 : (entry.score / entry.totalQuestions * 100).round()}%',
                style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}