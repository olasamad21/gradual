# Gradual – Change Tracker

This document tracks all modifications, additions, and removals made to the project architecture and codebase over time.

---

### [2026-05-22 18:08:00] - Architecture Pivot: Weekly Quizzes & Streaks

**Added:**
- Created `CHANGELOG.md` to track ongoing project modifications.
- Decided on a new Firestore structure to separate Daily Content from Quizzes.
  - Planned: `content_software_engineering` collection for daily words (no quizzes).
  - Planned: `quizzes_software_engineering` collection for a single 10-question weekly quiz available on Saturdays.
- Planned: Weekly streak logic requiring a score of 3+ on the Saturday quiz.

**Removed:**
- Deprecating the daily, difficulty-tiered quiz system (Junior/Senior/Tech Lead).

**Next Steps:**
- Write Python script to parse `content_json.json` and upload to the new Firestore structure.
- Refactor Flutter models (`DailyContent`) and create `WeeklyQuiz` models.
- Refactor Flutter UI and Streak logic to support the Saturday-only requirement.

### [2026-05-22 18:09:00] - Created Python Import Script

**Added:**
- Created `import_content.py` to parse `content_json.json`.
- Script splits `quiz_questions` from daily content and batches them into a single `quizzes_software_engineering` document every Saturday.

### [2026-05-22 18:27:00] - Refactored Flutter Data Models

**Added:**
- Created `WeeklyQuiz` model (`lib/core/models/weekly_quiz_model.dart`) to represent the new 10-question Saturday quizzes.
- Added `getWeeklyQuiz` method to `ContentRepository` (`lib/core/repositories/content_repository.dart`).

**Modified:**
- Stripped difficulty tiers (`quiz_junior`, `quiz_senior`, `quiz_lead`) from `DailyContent` model (`lib/core/models/daily_content_model.dart`).
- Refactored `QuizQuestion` and `QuizItem` to track `sourceWord` instead of difficulty (`lib/features/quiz/quiz_models.dart`).

### [2026-05-22 19:40:00] - Refactored Flutter UI and State for Weekly Quizzes

**Modified:**
- `lib/features/quiz/quiz_providers.dart`: Updated to fetch `WeeklyQuiz` instead of daily content and removed difficulty parameter from `finalizeResults`.
- `lib/router/app_router.dart`: Removed the difficulty parameter from the `/quiz` route.
- `lib/features/daily_word/daily_word_screen.dart`: Replaced the Junior/Senior/Lead bottom sheet with a single "Take Weekly Quiz" button that is only active on Saturdays.
- `lib/features/quiz/quiz_screen.dart`: Completely overhauled the UI to remove all difficulty/tab logic. It now processes the 10 weekly questions sequentially and displays a single, unified result screen.
### [2026-05-22 19:30:00] - Weekly Streak & Heatmap Refactor

**Added:**
- Week utilities in `lib/core/utils/date_utils.dart` (`saturdayOfWeekContaining`, `previousSaturday`, `endOfDay`, etc.).
- `WeeklyScoreTier` helpers and weekly `ActivityLogEntry` shape in `lib/core/models/user_model.dart`.
- `UserRepository.recordWeeklyQuiz` — Saturday-only streak writes (score 3+ continues, 0–2 resets).
- Score-tier heatmap colors and missed-Saturday grey in `lib/features/streak/streak_heatmap_widget.dart`.

**Modified:**
- `liveStreak` and `hasCompletedThisWeek()` on `AppUser` for weekly deadline validation.
- `quiz_providers.dart`, `quiz_screen.dart` (0–10 score tiers, streak modal, break messaging).
- `profile_screen.dart`, `streak_providers.dart`, `streak_success_modal.dart`, `daily_word_screen.dart`.

**Removed:**
- `lib/core/enums/difficulty_level.dart`
- `lib/features/quiz/quiz_difficulty_modal.dart`
- Daily `recordActivity` / difficulty-based streak logic.

### [2026-05-22 20:00:00] - Fix Home/Profile Loading Loop

**Fixed:**
- `appUserProvider` no longer uses `Stream.empty()` during auth load (prevents loading flicker).
- `todayContentProvider` / `weeklyQuizProvider` use `valueOrNull` instead of `.value` (no throw loop).
- Home screen decouples header/heatmap loading from concept section.
- Profile retry invalidates `appUserProvider`; keeps previous profile visible while refreshing.
- `main.dart` wires `DefaultFirebaseOptions.currentPlatform`.
- Clearer empty state when today's date is before imported content (May 24, 2026).

### [2026-05-22 21:00:00] - Firestore Permission Handling

**Added:**
- `firestore.rules` and `FIRESTORE_RULES.md` for authenticated reads on `users`, `content_*`, `quizzes_*`.
- `lib/core/errors/firestore_errors.dart` — detects `permission-denied`, no retry on permission errors.
- `FirestorePermissionWidget` for clear "Access denied" UI.

**Modified:**
- `user_repository.dart`, `content_repository.dart` — guard streams/futures.
- `daily_word_screen.dart`, `profile_screen.dart` — permission-specific messages, retry only on network-like errors.
