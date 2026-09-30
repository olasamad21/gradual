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

### [2026-09-30] - Content Pipeline and Concept Data Layer

**Added:**
- seed_concepts.py tool for validating and uploading new concept definitions.
- Unit tests for seeding validation in 	ests/test_seed_concepts.py.
- New Flutter models: Concept, ConceptQuiz, and DailySet in lib/core/models/concept_model.dart.
- 	odaysConceptsProvider in lib/features/daily_word/concept_providers.dart.
- getDailySet, getConceptsByIds, and getTodaysConcepts in ContentRepository.
- Local date formatting utilities in lib/core/utils/date_utils.dart.

**Modified:**
- createOrUpdateUser in UserRepository now uses merge: true with strict profile fields (email, ield_of_study), fixing an issue where streak data could be overwritten by outdated client objects.
- irestore.rules updated to allow authenticated reads for concepts_* and daily_sets_*.


### [2026-09-30 20:15:00] - Concept Implementation & Streak Engine

**Added:**
- Created `StreakEngine` in `lib/core/services/streak_engine.dart` containing pure Dart calculations for daily streaks, bypassing legacy Firestore limitations, tolerant to malformed DB entries.
- Added exhaustive tests for `StreakEngine` ensuring resilience over gaps, DST boundaries, month/year boundaries, and malformed inputs.
- Created `field_utils.dart` to determine `effectiveField` for concepts.
- Added `recordConceptRead`, `resetStatsIfNeeded`, and `initNewUserIfMissing` in `UserRepository`.
- Added `statsResetProvider` for one-time legacy user resets.

**Modified:**
- `AppUser` model rewritten to use `StreakEngine` for its `liveStreak` logic and provide access to the raw activity log json.
- `ActivityLogEntry` updated to properly parse missing fields gracefully and store `conceptsRead`.
- `seed_concepts.py` updated to strictly reject duplicated concepts with different content definitions, checking both local files and Firestore during commit.
- Testing for `seed_concepts.py` expanded for database errors and mock glob validation.
- Wired up Providers in `quiz_providers.dart`, `concept_providers.dart`, and `daily_word_providers.dart` to use `effectiveField(user)`.
- Wired `onboarding_view_model.dart` to correctly init users using `initNewUserIfMissing` before merging profiles.

### [2026-09-30 20:33:00] - Concept Screen Redesign (Phase 2 UI)

**Added:**
- Created `ConceptCard` widget to display terms with chips, animated expansion for details (definition, analogies, related), and a "Got it" completion toggle.
- Created `TodayConceptsController` extending `AsyncNotifier` to expose today's loaded concepts, current user's read state, and an optimistic `markRead` update.
- Created widget tests for `ConceptCard` behavior and layout validation.

**Modified:**
- Remodeled `DailyWordScreen` body to map through a list of 3 `ConceptCard`s instead of reading a single daily snippet.
- Implemented real-time check logic to render the daily success modal once the first card of the day is marked as read, passing in the newly architected local liveStreak.
- Removed legacy `_emptyConceptMessage` hardcoded constraints since content seeding natively handles fallback states now.
