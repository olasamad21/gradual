## Gradual – Implementation Status

This file tracks **what has been implemented vs what is still pending** for the Gradual MVP, based on the PRD in [`PRD.md`](PRD.md).  
Update this file whenever you add or change features.

---

## High-Level Summary

- **Core Flutter + Firebase + Riverpod scaffolding**: **Done (MVP)**
- **Onboarding, profile, daily word, quiz, streak/heatmap UX**: **Implemented (MVP, can be refined)**
- **Notifications scheduling, offline caching, AI content pipeline, production hardening**: **Not fully implemented**

---

## 3. Functional Requirements – Status

### 3.1 Onboarding & Profile

| ID    | Feature         | Status           | Notes |
|-------|-----------------|------------------|-------|
| FR-01 | Sign Up/Login   | **Done (MVP)**   | Google Sign-In via Firebase implemented in `lib/features/onboarding/onboarding_view_model.dart` and used by `OnboardingScreen`. |
| FR-02 | Field Selection | **Done (MVP)**   | Field-of-study dropdown (Software Engineering) implemented in `OnboardingScreen`; stored on `AppUser.fieldOfStudy`. |
| FR-03 | Profile View    | **Done (MVP)**   | `ProfileScreen` shows email, field, current streak, and a heatmap; full-year visualization can be expanded later. |

### 3.2 The Daily Learning Loop

| ID    | Feature              | Status                 | Notes |
|-------|----------------------|------------------------|-------|
| FR-04 | Daily Notification   | **Placeholder/Pending**| `NotificationService` stub exists in `lib/features/daily_word/notification_service.dart`; real scheduled notifications not yet wired. |
| FR-05 | Word Card            | **Done (MVP)**         | `DailyWordScreen` + `WordCard` implement daily concept card with definition, analogy, and code snippet flip. |
| FR-06 | Archive/History      | **Not Started**        | No dedicated history screen yet; only today’s content is fetched by `todayContentProvider`. |

### 3.3 The Quiz System (Tiered Difficulty)

| ID    | Feature             | Status           | Notes |
|-------|---------------------|------------------|-------|
| FR-07 | Quiz Entry          | **Done (MVP)**   | Quiz launched from daily word flow (`Test Knowledge` button navigates to `QuizScreen`). |
| FR-08 | Difficulty Selection| **Done (MVP)**   | Difficulty selected via `QuizDifficultyModal` (Junior/Senior/Tech Lead). |
| FR-09 | Question Logic      | **Done (MVP)**   | `QuizController` builds questions from today’s content; logic can be extended to enforce New/Review/Challenge mix. |
| FR-10 | Immediate Feedback  | **Partially Done** | Questions advance on tap; basic correctness is tracked, but explicit green/red option feedback visuals can be enhanced. |

### 3.4 Gamification (Streak & Heatmap)

| ID    | Feature               | Status           | Notes |
|-------|-----------------------|------------------|-------|
| FR-11 | Home Header Heatmap   | **Done (MVP)**   | 14-day heatmap strip implemented via `StreakHeatmapWidget` and used on `DailyWordScreen`. |
| FR-12 | Streak Logic          | **Done (MVP)**   | `UserRepository.recordActivity` updates streak using server-like timestamps (client-side for now); can be moved fully to server logic later. |
| FR-13 | Success Modal         | **Done (MVP)**   | `StreakSuccessModal` shown after quiz results to reinforce today’s contribution. |
| FR-14 | Color Intensity Logic | **Done (MVP)**   | Heatmap colors map to difficulty (light/medium/dark green) in `StreakHeatmapWidget`; tuning still possible. |

---

## 4. Technical Architecture – Status

| Area                | Status         | Notes |
|---------------------|----------------|-------|
| Flutter app shell   | **Done (MVP)** | `main.dart`, `lib/app.dart`, and `lib/router/app_router.dart` configure Firebase init, Riverpod, routing, and theming. |
| Models & repositories | **Done (MVP)** | `AppUser`, `DailyContent`, `DifficultyLevel`, and corresponding repositories are implemented under `lib/core/`. |
| Firebase config     | **Pending**    | `Firebase.initializeApp()` is called, but linking to generated `firebase_options.dart` still requires running `flutterfire configure`. |
| Notifications (FCM) | **Placeholder**| `NotificationService` is present; no full scheduling or background handling pipeline yet. |

---

## 6. Non-Functional Requirements – Status

| Requirement     | Status              | Notes |
|-----------------|---------------------|-------|
| Performance     | **Partially Addressed** | Architecture is lightweight; no explicit performance profiling or 2-second SLA checks yet. |
| Offline Mode    | **Not Implemented** | No local cache layer; app currently assumes network access for daily word and quiz/streak updates. |
| Scalability     | **Partially Addressed** | Firestore collections are structured to support multiple fields (`content_<field>`), but only Software Engineering is used so far. |

---

## 7. Risks & Mitigations – Status

| Risk / Mitigation                   | Status        | Notes |
|-------------------------------------|---------------|-------|
| Server-time-based streak protection | **Not Implemented** | Streak is updated in app code; no Cloud Functions or server-side enforcement of `Timestamp.now()` yet. |
| Content pipeline (30 + 60 days)     | **Not Implemented** | No tooling or scripts exist yet to pre-generate and load content into Firestore. |

---

## How to Update This File

- **When you implement a feature**:  
  - Change its row’s **Status** (e.g., from `Not Started` → `Done (MVP)`), and update the **Notes** with the main file(s) involved.
- **When you refine behavior** (e.g., improve feedback visuals, add offline cache):  
  - Adjust the status from **Partially Done** to **Done**, and briefly describe what changed.
- **When you add new PRD items**:  
  - Add new rows under the appropriate section (Onboarding, Daily Loop, Quiz, Gamification, Technical, etc.) with initial status `Not Started`.

