# Gradual

A micro-learning app for Software Engineering, built with Flutter and Firebase.

**Live Demo:** [https://gradual-852ea.web.app](https://gradual-852ea.web.app)

*(Insert screenshot here)*

## Tech Stack
- **Framework:** Flutter (Web & Mobile)
- **State Management:** Riverpod
- **Authentication:** Firebase Auth (Google Sign-In)
- **Database:** Cloud Firestore
- **Hosting:** Firebase Hosting

## Bringing Gradual to the Web
Gradual was originally built for mobile. Migrating it to a fully functioning web app involved several architectural considerations:
1. **Compatibility Audit:** First, we scanned the codebase to ensure no direct dependencies on `dart:io` or native mobile plugins would block the web build. 
2. **Platform-Split Authentication:** Browsers frequently block popups that aren't tied directly to user gestures. We split the Google Sign-In logic using `kIsWeb`: retaining the `google_sign_in` plugin for Android, but invoking `FirebaseAuth.instance.signInWithPopup()` synchronously on the button press for the Web.
3. **Responsive Constraints:** We wrapped the root `MaterialApp.builder` in a centered `ConstrainedBox` with a max width of 500px to prevent the UI from stretching uncomfortably on wide desktop monitors.
4. **Direct URL Routing Guard:** On the web, users can navigate directly to protected routes (e.g., `/#/profile`). We implemented a route guard in `AppRouter` that bounces unauthenticated users back to the `RootGatekeeper` to resolve their session before granting access.
5. **Firebase Web Registration:** Configured `firebase_options.dart` and deployed securely to Firebase Hosting with SPA rewrite rules.
