import re

with open('lib/features/daily_word/daily_word_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# 1. Update imports
new_imports = """
import '../../core/errors/firestore_errors.dart';
import '../../core/firebase/firebase_providers.dart';
import '../../core/models/daily_content_model.dart';
import '../../core/models/user_model.dart';
import '../../shared/widgets/firestore_permission_widget.dart';
import '../../shared/widgets/loading_indicator.dart';
import '../../shared/widgets/primary_button.dart';
import '../streak/streak_heatmap_widget.dart';
import '../streak/streak_success_modal.dart';
import '../quiz/quiz_result_cache_provider.dart';
import '../quiz/quiz_screen.dart';
import '../quiz/quiz_models.dart';
import 'concept_card.dart';
import 'today_concepts_controller.dart';
import 'daily_word_providers.dart';
import 'word_card.dart';
"""

content = re.sub(r"import '../../core/errors/firestore_errors\.dart';[\s\S]*?import 'word_card\.dart';", new_imports.strip(), content)

# 2. Remove _firstContentDateId and _emptyConceptMessage
content = re.sub(r"/// First date with imported content.*?const _firstContentDateId = '2026-05-24';", "", content, flags=re.DOTALL)
content = re.sub(r"  String _emptyConceptMessage\(\) \{[\s\S]*?  \}", "", content)

# 3. Update build()
old_build_start = """  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(appUserProvider);
    final contentAsync = ref.watch(todayContentProvider);"""

new_build_start = """  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(appUserProvider);
    final conceptsAsync = ref.watch(todayConceptsControllerProvider);
    
    ref.listen<AsyncValue<TodayConceptsState>>(
      todayConceptsControllerProvider,
      (previous, next) {
        final prevData = previous?.valueOrNull;
        final nextData = next.valueOrNull;
        
        if (prevData != null && nextData != null) {
          if (prevData.readCount == 0 && nextData.readCount == 1) {
            showDialog(
              context: context,
              builder: (ctx) => StreakSuccessModal(
                streakCount: nextData.liveStreak,
                isPerfectDay: false,
              ),
            );
          }
        }
      },
    );"""
content = content.replace(old_build_start, new_build_start)

# 4. Update the _buildConceptSection call in build()
old_call = """_buildConceptSection(
                          context,
                          ref,
                          userAsync: userAsync,
                          contentAsync: contentAsync,
                          user: cachedUser,
                        )"""
new_call = """_buildConceptSection(
                          context,
                          ref,
                          userAsync: userAsync,
                          conceptsAsync: conceptsAsync,
                          user: cachedUser,
                        )"""
content = content.replace(old_call, new_call)


# 5. Replace _buildConceptSection definition completely
old_section = re.search(r"  Widget _buildConceptSection\([\s\S]*?^}$", content, flags=re.MULTILINE).group(0)

new_section = """  Widget _buildConceptSection(
    BuildContext context,
    WidgetRef ref, {
    required AsyncValue<AppUser?> userAsync,
    required AsyncValue<TodayConceptsState> conceptsAsync,
    required AppUser? user,
  }) {
    if (userAsync.isLoading && user == null) {
      return const LoadingIndicator(label: "Loading today's concepts...");
    }

    return conceptsAsync.when(
      data: (state) {
        if (state.concepts.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.hourglass_empty_rounded, size: 48, color: Colors.grey.shade300),
                const SizedBox(height: 12),
                Text(
                  'No concepts available.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 15),
                ),
              ],
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 3,
                  height: 16,
                  decoration: BoxDecoration(
                    color: const Color(0xFF388E3C),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "${state.readCount} of ${state.concepts.length} today",
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF6B7280),
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                if (state.isPerfectDay)
                  const Text(
                    "Perfect day!",
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF388E3C),
                    ),
                  ),
              ],
            ),
            if (state.isFallback) ...[
              const SizedBox(height: 4),
              const Text(
                "Showing the latest available set",
                style: TextStyle(fontSize: 11, color: Colors.orange),
              ),
            ],
            const SizedBox(height: 12),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.only(bottom: 20),
                itemCount: state.concepts.length,
                itemBuilder: (context, index) {
                  final concept = state.concepts[index];
                  final isRead = state.readConceptIds.contains(concept.id);
                  return ConceptCard(
                    concept: concept,
                    isRead: isRead,
                    onMarkRead: () {
                      ref.read(todayConceptsControllerProvider.notifier).markRead(concept.id);
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
            PrimaryButton(
              label: _isSaturday
                  ? 'Take Weekly Quiz'
                  : 'Quiz Unlocks on Saturday',
              onPressed: _isSaturday
                  ? () {
                      final cache = ref.read(quizResultCacheProvider).value ?? {};
                      final isCompleted = user?.hasCompletedThisWeek() ?? false;

                      if (isCompleted) {
                        final allAnswers = Map<String, List<QuizAnswer>>.from(cache);
                        allAnswers.putIfAbsent('weekly', () => []);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => QuizResultScreen(
                              allAnswers: allAnswers,
                              initialDifficultyId: 'weekly',
                            ),
                          ),
                        );
                      } else {
                        Navigator.pushNamed(context, '/quiz');
                      }
                    }
                  : null,
            ),
            const SizedBox(height: 28),
          ],
        );
      },
      loading: () => const LoadingIndicator(label: "Loading today's concepts..."),
      error: (e, _) {
        if (FirestoreErrors.isPermissionDenied(e)) {
          return const FirestorePermissionWidget();
        }
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.wifi_off_rounded, size: 48, color: Colors.grey.shade300),
              const SizedBox(height: 12),
              Text(
                'Failed to load today\\'s concepts.',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 15),
              ),
              if (FirestoreErrors.shouldRetry(e)) ...[
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => ref.invalidate(todayConceptsControllerProvider),
                  child: const Text('Retry'),
                ),
              ],
            ],
          ),
        );
      },
    );
  }"""
content = content.replace(old_section, new_section)

# Finally, write it back
with open('lib/features/daily_word/daily_word_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)
