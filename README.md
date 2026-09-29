# Gradual

A micro-learning app for Software Engineering, built with Flutter and Firebase.

**Live Demo:** [https://gradual-852ea.web.app](https://gradual-852ea.web.app)

## Tech Stack
- **Framework:** Flutter (Web & Android)
- **State Management:** Riverpod
- **Authentication:** Firebase Auth (Google Sign-In)
- **Database:** Cloud Firestore
- **Hosting:** Firebase Hosting

## Features
- **Google Sign-In:** Secure authentication flow natively on Android and via popup on the Web.
- **Daily Word:** A micro-learning view displaying a new software engineering term each day.
- **Weekly Quiz:** A progressive assessment mode that tests knowledge retention across multiple difficulty levels.
- **Learning Streak:** Visual streak tracking with a 30-day commit-style heatmap on the profile screen.
- **Cross-Platform Support:** A unified codebase serving both an Android application and a responsive Web SPA.

## Project Structure
The codebase follows a feature-first architecture pattern:
- **Feature-first Folders:** UI and state logic are grouped by feature (e.g., `lib/features/auth`, `lib/features/daily_word`, `lib/features/quiz`) rather than by type.
- **Repository Pattern:** All Firestore and external data access is abstracted into dedicated repositories (e.g., `UserRepository`, `ContentRepository`) located in `lib/core/repositories/`.
- **State Management:** Riverpod `AsyncNotifier`s manage state and handle business logic seamlessly between the UI and repositories.

## Bringing Gradual to the Web
Gradual was originally built for mobile. Migrating it to a fully functioning web app involved several architectural considerations:
1. **Compatibility Audit:** First, I scanned the codebase to ensure no direct dependencies on `dart:io` or native mobile plugins would block the web build. 
2. **Platform-Split Authentication:** Browsers frequently block popups that aren't tied directly to user gestures. I split the Google Sign-In logic using `kIsWeb`: retaining the `google_sign_in` plugin for Android, but invoking `FirebaseAuth.instance.signInWithPopup()` synchronously on the button press for the Web.
3. **Responsive Constraints:** I wrapped the root `MaterialApp.builder` in a centered `ConstrainedBox` with a max width of 500px to prevent the UI from stretching uncomfortably on wide desktop monitors.
4. **Direct URL Routing Guard:** On the web, users can navigate directly to protected routes (e.g., `/#/profile`). I implemented a route guard in `AppRouter` that bounces unauthenticated users back to the `RootGatekeeper` to resolve their session before granting access.
5. **Firebase Web Registration:** Configured `firebase_options.dart` and deployed to Firebase Hosting; data protected by Firestore security rules (owner-only user documents, read-only content collections) with SPA rewrite rules.

## Run Locally
1. **Prerequisites:** Flutter SDK and Firebase CLI must be installed.
2. **Clone the repository:**
   ```bash
   git clone https://github.com/olasamad21/gradual.git
   cd gradual
   ```
3. **Install dependencies:**
   ```bash
   flutter pub get
   ```
4. **Configure Firebase:**
   ```bash
   firebase login
   dart pub global activate flutterfire_cli
   flutterfire configure --project=gradual-852ea
   ```
5. **Run the app:**
   ```bash
   flutter run -d chrome    # For Web testing
   flutter run              # For Android testing
   ```
