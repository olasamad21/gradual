# Gradual

A micro-learning app for Software Engineering, built with Flutter and Firebase. It helps users learn a few concepts every day and retain knowledge over time.

## Product Description
Gradual delivers exactly 3 core software engineering concepts each day. Instead of overwhelming users with long articles, each concept is presented as an interactive, expandable card containing a definition, an analogy, real-world examples, and related terms. Users build a daily learning streak by marking concepts as read. Knowledge retention is reinforced through dynamic quizzes that pull from the user's personal reading history.

## Schema

### Users (`users/{uid}`)
- `email`: User's email
- `field_of_study`: Default 'software_engineering'
- `current_streak`: Current daily streak count
- `last_activity_date`: Timestamp of the last activity
- `activity_log`: Map of `yyyy-MM-dd` -> `ActivityLogEntry`
  - `ActivityLogEntry`: Tracks `concepts_read` (List of IDs) and `quiz_score` / `quiz_total`.

### Concepts (`concepts_software_engineering/{conceptId}`)
- `term`: The concept name
- `category`: Classification (e.g., architecture, concurrency)
- `level`: beginner, intermediate, advanced
- `definition`: Clear definition
- `analogy`: Relatable analogy
- `real_world_example`: Practical use case
- `confused_with`: Common misconceptions
- `related`: Array of related concept IDs

### Daily Sets (`daily_sets_software_engineering/{dateId}`)
- `date_id`: `yyyy-MM-dd`
- `concept_ids`: Array of exactly 3 concept IDs for that day.

## Content Seeding

Content is seeded using the Python script `seed_concepts.py` utilizing the Firebase Admin SDK.

**Setup:**
1. Place a valid `serviceAccountKey.json` at the root of the project.
2. Ensure you have `firebase-admin` installed (`pip install firebase-admin`).

**Weekly Content Calendar Rule:**
- The week always starts on **Monday**.
- 1 week requires exactly **7 sets** of **3 concepts** (Total: 21 concepts per week).
- Organize your content files in the `content/` folder (e.g., `content/week_01.json`).

**Command:**
```bash
# Dry run (validates schema, relationships, and formatting locally without writing to Firestore)
python seed_concepts.py content/week_01.json

# Commit to Firestore
python seed_concepts.py content/week_01.json --commit
```

## Launch Checklist
- **Keep ahead:** Always maintain at least 3 to 4 weeks of content uploaded ahead of the current date to prevent users from encountering empty days.

## Running Tests
Unit and widget tests are built into the Flutter framework. To run the full suite:
```bash
flutter test
```
