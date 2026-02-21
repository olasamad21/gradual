## Gradual – Product Requirements Document (PRD)

**Project Name**: Gradual (Working Title)  
**Version**: 1.0 (MVP)  
**Status**: Ready for Development  
**Date**: February 17, 2026

---

## 1. Executive Summary

Gradual is a **mobile micro-learning application** designed to help students master terminology in their specific field of study, starting with **Software Engineering**.

- **The Problem**: Students often struggle to retain technical jargon and concepts because they try to *cram* information instead of engaging with it consistently.
- **The Solution**: A low-friction, daily habit app that:
  - Introduces **one concept per day**
  - Reinforces it with a **tiered difficulty quiz**
  - Visualizes progress using a **GitHub-style contribution graph** to encourage consistency and streaks

The MVP will focus on Software Engineering content and core habit-forming mechanics (daily word, quiz, streak, and heatmap).

---

## 2. Target Audience

- **Primary User**: University students (initially final-year **Software Engineering** students) preparing for exams or job interviews.

- **User Persona – "Alex"**:
  - **Goal**: Learn technical terms without feeling overwhelmed.
  - **Pain Points**:
    - Finds textbooks boring and dense.
    - Often forgets what was studied the previous day.
  - **Motivations**:
    - Likes seeing **visual progress** (streaks, graphs).
    - Enjoys **testing knowledge** and getting immediate feedback.

---

## 3. Functional Requirements

### 3.1 Onboarding & Profile

| ID    | Feature           | Description                                                                                   | Priority |
|-------|-------------------|-----------------------------------------------------------------------------------------------|----------|
| FR-01 | Sign Up/Login     | User creates an account via **Google Sign-In** (Firebase Auth).                              | P0       |
| FR-02 | Field Selection   | User selects their **field of study** (e.g., "Software Engineering").                        | P0       |
| FR-03 | Profile View      | Displays **User Name**, **Current Streak Count**, and the **full-year heatmap**.            | P1       |

### 3.2 The Daily Learning Loop

| ID    | Feature            | Description                                                                                       | Priority |
|-------|--------------------|---------------------------------------------------------------------------------------------------|----------|
| FR-04 | Daily Notification | Push notification sent at a user-defined time (default **9:00 AM**). Opens the **Word of the Day**. | P0       |
| FR-05 | Word Card          | Displays the daily word, simple definition, analogy, and a code snippet/practical example.      | P0       |
| FR-06 | Archive/History    | Users can view a read-only list of previously learned words.                                     | P2       |

### 3.3 The Quiz System (Tiered Difficulty)

| ID    | Feature             | Description                                                                                             | Priority |
|-------|---------------------|---------------------------------------------------------------------------------------------------------|----------|
| FR-07 | Quiz Entry          | Accessed after reading the Word Card. User must select a difficulty level to start.                    | P0       |
| FR-08 | Difficulty Selection| Three modes: **Junior** (Definitions), **Senior** (Syntax/Application), **Tech Lead** (System Design/Trade-offs). | P0       |
| FR-09 | Question Logic      | Quiz consists of **3 questions**: 1 New (current topic), 1 Review (past topic), 1 Challenge.          | P1       |
| FR-10 | Immediate Feedback  | Visual feedback (**Green/Red**) immediately after selecting an answer.                                | P0       |

### 3.4 Gamification (The Streak & Heatmap)

| ID    | Feature                | Description                                                                                                              | Priority |
|-------|------------------------|--------------------------------------------------------------------------------------------------------------------------|----------|
| FR-11 | Home Header Heatmap    | A rolling **14-day** contribution graph displayed at the top of the Home Screen.                                       | P0       |
| FR-12 | Streak Logic           | Streak increments if the user completes the **Word OR Quiz** within 24 hours; resets if a day is missed.              | P0       |
| FR-13 | Success Modal          | Upon quiz completion, a modal pops up showing the **“Today”** box filling with color.                                  | P0       |
| FR-14 | Color Intensity Logic  | Heatmap box color depends on effort: **Light Green** (Read Word), **Medium Green** (Passed Junior Quiz), **Dark Green** (Passed Senior/Lead Quiz). | P1       |

---

## 4. Technical Architecture

### 4.1 Tech Stack

- **Frontend**: Flutter (Dart) – Cross-platform for iOS and Android.
- **Backend**: Firebase (Backend-as-a-Service).
- **Database**: Cloud Firestore (NoSQL).
- **Authentication**: Firebase Authentication (Google Sign-In).
- **Notifications**: Firebase Cloud Messaging (FCM).

### 4.2 Data Model (Schema Overview)

**Collection: `users`**

```json
{
  "uid": "string",
  "email": "string",
  "field_of_study": "software_engineering",
  "current_streak": 0,
  "last_activity_date": "timestamp",
  "activity_log": {
    "2023-10-27": {
      "status": "completed",
      "difficulty": "senior",
      "score": 3
    }
  }
}
```

**Collection: `content_software_engineering`**

```json
{
  "date_id": "2023-10-27",
  "word": "Idempotency",
  "definition": "string",
  "analogy": "string",
  "code_snippet": "string",
  "quiz_junior": { "question": "...", "options": [], "answer": "..." },
  "quiz_senior": { "question": "...", "options": [], "answer": "..." },
  "quiz_lead":   { "question": "...", "options": [], "answer": "..." }
}
```

> **Note**: Future fields of study (e.g., Nursing, Law) should follow a similar collection structure (e.g., `content_nursing`, `content_law`) without requiring major code changes.

---

## 5. User Interface (UX) Flow

### 5.1 Home Screen

- **Header**: `"Good Morning, Alex"` (or time-contextual greeting)  
  - Includes a **mini heatmap row** (rolling 14-day view).
- **Main Card**:  
  - Title: `"Today's Concept: Recursion"` (example).  
  - CTA Button: **"Learn Now"** (opens Learning Screen).

### 5.2 Learning Screen

- **Content**:
  - Flip-card style animation:
    - **Front**: Term and simple definition.
    - **Back**: Code snippet or practical example and analogy.
- **Action**:
  - Bottom button: **"Test Knowledge"** → opens **Quiz Difficulty Modal**.

### 5.3 Quiz Difficulty Modal

- Title: **"Choose your challenge level"**  
- Options:
  - **Junior** – Definition-focused questions.
  - **Senior** – Syntax/application questions.
  - **Tech Lead** – System design / trade-off questions.

### 5.4 Quiz Screen

- **Structure**:
  - **3 questions** per session:
    - 1 × New (today's concept)
    - 1 × Review (previous concepts)
    - 1 × Challenge
  - **Progress bar** (e.g., 1/3, 2/3, 3/3).
- **Feedback**:
  - Immediate visual feedback after each answer (Green = correct, Red = incorrect).

### 5.5 Result Screen (The “Hook”)

- Display: `"3/3 Correct!"` (or relevant score).
- Animation:  
  - The **heatmap box for today** zooms in and transitions to the appropriate green intensity.
- CTA: **"See you tomorrow."**

---

## 6. Non-Functional Requirements

- **Performance**:  
  - The app must load the **Daily Word** in **under 2 seconds** on a typical mobile data connection.

- **Offline Mode**:  
  - If the user has no internet:
    - Show the **last cached word** (read-only).
    - Quiz submission and streak updates require an active internet connection.

- **Scalability**:  
  - Database structure must support adding new fields (e.g., Nursing, Law) without changing core app logic.
  - Content collections for each field should follow a consistent schema.

---

## 7. Risks & Mitigation

- **Risk**: Users cheat the system by changing their phone date to preserve/fix their streak.  
  - **Mitigation**: Use `admin.firestore.Timestamp.now()` (server time) for all streak and activity calculations, not the device’s local time.

- **Risk**: Content runs out.  
  - **Mitigation**:
    - Launch with at least **30 days of pre-written content**.
    - Use AI tools (e.g., Gemini / GPT) to generate the next **60 days** in bulk, with human review before publishing.

---

## 8. Development Roadmap (Phases)

- **Phase 1 (Week 1)**:  
  - Setup Flutter project.  
  - Configure Firebase connection.  
  - Implement Google Auth (Firebase Authentication).

- **Phase 2 (Week 2)**:  
  - Build the **Word Card** UI.  
  - Fetch daily content from Firestore.

- **Phase 3 (Week 3)**:  
  - Build the **Quiz UI** and **difficulty selection logic**.  
  - Implement the 3-question structure (New, Review, Challenge).

- **Phase 4 (Week 4)**:  
  - Implement **streak calculation logic** using server time.  
  - Build the **heatmap widget** and success modal animations.

---

## 9. Out of Scope (For MVP)

- Additional fields of study beyond **Software Engineering** (can be added post-MVP).  
- Social features (leaderboards, sharing scores).  
- Web app or desktop versions (mobile-only for v1.0).

