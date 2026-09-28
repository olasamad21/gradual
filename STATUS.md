## Gradual – Implementation Status

This file tracks **what has been implemented vs what is still pending** for the Gradual MVP, based on the PRD in `PRD.md`.  
Update this file whenever you add or change features.

---

## High-Level Summary & Completed Features

The system already has several fully functional features implemented as part of the MVP:

- **Core Architecture**: Flutter + Firebase + Riverpod scaffolding is completely set up.
- **User Authentication**: Google Sign-In integration via Firebase (`lib/features/auth`).
- **Onboarding & Personalization**: Users can select their field of study (`Software Engineering`) which is saved to their profile (`lib/features/onboarding`).
- **User Profile Dashboard**: View displaying email, field of study, weekly streak, and activity heatmap (`lib/features/profile`).
- **Daily Learning Concept Card**: Interactive flashcard-style word of the day with definition, analogy, and code snippet flip (`lib/features/daily_word`).
- **Weekly Quiz (Saturday)**: Single 10-question quiz from `quizzes_<field>`; button enabled only on Saturdays (`lib/features/quiz`, `lib/features/daily_word`).
- **Dynamic Quiz Engine**: Fetches weekly quiz via `weeklyQuizProvider`, with local caching via `shared_preferences` (`QuizResultCacheNotifier`).
- **Gamification / Weekly Streak**: `UserRepository.recordWeeklyQuiz` — score 3+ continues streak, 0–2 or skip breaks it (`lib/features/streak`).
- **Heatmap Visualization**: Activity grid colored by weekly quiz score tier (green/yellow/orange/red/grey) in `StreakHeatmapWidget`.
- **Content Import Pipeline**: `import_content.py` loads `content_json.json` into Firestore (`content_*` + `quizzes_*` collections).

**Currently Pending/Incomplete:**
- Scheduled Notifications (FCM).
- Full offline caching for content.
- Automated AI content generation pipeline (import script exists; generation is manual).

---

## 3. Functional Requirements – Status

### 3.1 Onboarding & Profile

| ID    | Feature         | Status           | Notes |
|-------|-----------------|------------------|-------|
| FR-01 | Sign Up/Login   | **Done (MVP)**   | Google Sign-In via Firebase implemented in `lib/features/onboarding/onboarding_view_model.dart` and used by `OnboardingScreen`. |
| FR-02 | Field Selection | **Done (MVP)**   | Field-of-study dropdown (Software Engineering) implemented in `OnboardingScreen`; stored on `AppUser.fieldOfStudy`. |
| FR-03 | Profile View    | **Done (MVP)**   | `ProfileScreen` shows email, field, weekly streak (`liveStreak`), and score-tier heatmap. |

### 3.2 The Daily Learning Loop

| ID    | Feature              | Status                 | Notes |
|-------|----------------------|------------------------|-------|
| FR-04 | Daily Notification   | **Placeholder/Pending**| `NotificationService` stub exists in `lib/features/daily_word/notification_service.dart`; real scheduled notifications not yet wired. |
| FR-05 | Word Card            | **Done (MVP)**         | `DailyWordScreen` + `WordCard` implement daily concept card with definition, analogy, and code snippet flip. |
| FR-06 | Archive/History      | **Not Started**        | No dedicated history screen yet; profile shows recent weekly quiz entries. |

### 3.3 The Quiz System (Weekly)

| ID    | Feature             | Status           | Notes |
|-------|---------------------|------------------|-------|
| FR-07 | Quiz Entry          | **Done (MVP)**   | `Take Weekly Quiz` on `DailyWordScreen`; Saturday-only. |
| FR-08 | Difficulty Selection| **Removed**      | Replaced by single weekly 10-question quiz. |
| FR-09 | Question Logic      | **Done (MVP)**   | `buildQuizFromWeekly` + `weeklyQuizProvider` from `quizzes_<field>`. |
| FR-10 | Immediate Feedback  | **Partially Done** | Questions advance on tap; review screen after submit. |

### 3.4 Gamification (Streak & Heatmap)

| ID    | Feature               | Status           | Notes |
|-------|-----------------------|------------------|-------|
| FR-11 | Home Header Heatmap   | **Done (MVP)**   | `StreakHeatmapWidget` on `DailyWordScreen`. |
| FR-12 | Streak Logic          | **Done (MVP)**   | `UserRepository.recordWeeklyQuiz`; `AppUser.liveStreak` validates Saturday deadline. |
| FR-13 | Success Modal         | **Done (MVP)**   | `StreakSuccessModal` after quiz when score ≥ 3. |
| FR-14 | Color Intensity Logic | **Done (MVP)**   | Heatmap: 8–10 green, 5–7 yellow, 3–4 orange, 0–2 red, missed Saturday grey. |

---

## 4. Technical Architecture – Status

| Area                | Status         | Notes |
|---------------------|----------------|-------|
| Flutter app shell   | **Done (MVP)** | `main.dart`, `lib/app.dart`, and `lib/router/app_router.dart` configure Firebase init, Riverpod, routing, and theming. |
| Models & repositories | **Done (MVP)** | `AppUser`, `DailyContent`, `WeeklyQuiz`, repositories under `lib/core/`. |
| Firebase config     | **Pending**    | `Firebase.initializeApp()` is called, but linking to generated `firebase_options.dart` still requires passing the platform options. |
| Notifications (FCM) | **Placeholder**| `NotificationService` is present; no full scheduling or background handling pipeline yet. |
| Content import      | **Done (MVP)** | `import_content.py` + `content_json.json` → Firestore collections. |

---

## 6. Non-Functional Requirements – Status

| Requirement     | Status              | Notes |
|-----------------|---------------------|-------|
| Performance     | **Partially Addressed** | Architecture is lightweight; no explicit performance profiling or 2-second SLA checks yet. |
| Offline Mode    | **Partially Addressed** | Quiz results are cached locally via `shared_preferences` (`QuizResultCacheNotifier`), but daily word and user state still assume network access. |
| Scalability     | **Partially Addressed** | Firestore collections are structured to support multiple fields (`content_<field>`), but only Software Engineering is used so far. |

---

## 7. Risks & Mitigations – Status

| Risk / Mitigation                   | Status        | Notes |
|-------------------------------------|---------------|-------|
| Server-time-based streak protection | **Not Implemented** | Streak is updated in app code; no Cloud Functions or server-side enforcement of `Timestamp.now()` yet. |
| Content pipeline (30 + 60 days)     | **Partially Done** | `import_content.py` loads JSON batches; ongoing content generation is manual. |

---

## How to Update This File

- **When you implement a feature**:  
  - Change its row’s **Status** (e.g., from `Not Started` → `Done (MVP)`), and update the **Notes** with the main file(s) involved.
- **When you refine behavior** (e.g., improve feedback visuals, add offline cache):  
  - Adjust the status from **Partially Done** to **Done**, and briefly describe what changed.
- **When you add new PRD items**:  
  - Add new rows under the appropriate section (Onboarding, Daily Loop, Quiz, Gamification, Technical, etc.) with initial status `Not Started`.
