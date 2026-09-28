# Gradual — Web Compatibility Audit Report

**Date:** 2026-09-29  
**Auditor:** Antigravity (read-only audit — no files modified)

---

## STEP 1: PROJECT SNAPSHOT

### Flutter & Dart Versions

| Item | Value |
|------|-------|
| Flutter | 3.38.5 (stable channel) |
| Dart | 3.10.4 |
| SDK constraint (pubspec.yaml L8) | `^3.10.4` |
| DevTools | 2.51.1 |

### Web Folder

> **⚠️ `web/` folder does NOT exist.**  
> There is no `index.html`, `manifest.json`, or web icons present. The project was created as an Android-only Flutter project.

### App Purpose & Features

**Gradual** is a micro-learning mobile app for Software Engineering students. Users learn one technical concept per day and take a weekly quiz every Saturday.

**Screens:**
- **RootGatekeeper** — Auth state router
- **OnboardingScreen** — Google Sign-In + field-of-study selection
- **DailyWordScreen** — Word of the day with definition, analogy, code snippet
- **WordCard** — Flippable flashcard widget
- **QuizScreen** — 10-question weekly quiz
- **QuizResultScreen** — Score display with review
- **QuizReviewScreen** — Answer-by-answer breakdown
- **ProfileScreen** — User profile with streak heatmap
- **PlaceholderScreen** — Unused route stubs

**Folder Structure:**
```
lib/
├── app.dart, main.dart, firebase_options.dart
├── core/
│   ├── errors/, firebase/, models/, repositories/
│   ├── services/, theme/, utils/, widgets/
├── features/
│   ├── auth/, daily_word/, onboarding/
│   ├── profile/, quiz/, streak/
├── router/
└── shared/widgets/
```

### Architecture

| Aspect | Implementation |
|--------|---------------|
| State management | Riverpod (`flutter_riverpod`) |
| Routing | `MaterialApp.onGenerateRoute` with custom `AppRouter` class |
| Architecture pattern | Feature-first folder structure, Repository pattern |
| Backend | Firebase (Auth, Firestore, Messaging) |

---

## STEP 2: DEPENDENCY AUDIT

### Dependencies (pubspec.yaml L10–L22)

| Package | Version | Web Support | Notes |
|---------|---------|-------------|-------|
| `flutter` (SDK) | 3.38.5 | ✅ Yes | Core framework |
| `cupertino_icons` | ^1.0.8 | ✅ Yes | Icon font, renders fine on web |
| `flutter_riverpod` | ^3.2.1 | ✅ Yes | Pure Dart, no platform dependency |
| `firebase_core` | ^4.4.0 | ✅ Yes | Has `firebase_core_web` resolved in lock file |
| `firebase_auth` | ^6.1.4 | ✅ Yes | Has `firebase_auth_web` resolved in lock file |
| `cloud_firestore` | ^6.1.2 | ✅ Yes | Has `cloud_firestore_web` resolved in lock file |
| `firebase_messaging` | ^16.1.1 | ⚠️ Partial | Has `firebase_messaging_web` but web FCM requires VAPID key, service worker config, and HTTPS |
| `google_sign_in` | ^6.2.1 | ⚠️ Partial | Has `google_sign_in_web` but requires a **web OAuth client ID** configured in Google Cloud Console and added to `index.html` as a `<meta>` tag |
| `shared_preferences` | ^2.5.4 | ✅ Yes | Has `shared_preferences_web`, uses `localStorage` on web |
| `flutter_native_splash` | ^2.4.7 | ⚠️ Partial | Web splash support exists but requires a `web: true` flag and `web/` folder to generate |

### Dev Dependencies (pubspec.yaml L24–L27)

| Package | Version | Web Support | Notes |
|---------|---------|-------------|-------|
| `flutter_test` (SDK) | — | ✅ Yes | Standard test runner |
| `flutter_lints` | ^6.0.0 | ✅ Yes | Lint rules only, no runtime impact |

---

## STEP 3: CODE-LEVEL BLOCKERS

### 3.1 `dart:io` / `dart:ffi` / Platform Channels

| Check | Result |
|-------|--------|
| `dart:io` imports | ❌ **None found** across all 36 Dart files |
| `dart:ffi` imports | ❌ None found |
| `MethodChannel` / `EventChannel` | ❌ None found |
| Custom native code (android/ios Kotlin/Swift) | UNVERIFIED — did not scan native folders, but no channel references exist in Dart code |
| `Platform.isAndroid` etc. without `kIsWeb` | ❌ None found in app code. `firebase_options.dart` uses `kIsWeb` correctly (L19) |

### 3.2 Local Storage

| Usage | File | Lines | Web Impact |
|-------|------|-------|------------|
| `SharedPreferences` | [local_storage_service.dart](file:///c:/Users/samad/Documents/LeadCityProjects/gradual/lib/core/services/local_storage_service.dart) | L1, L10, L16 | ✅ Works — uses `localStorage` on web |
| `SharedPreferences` | [quiz_result_cache_provider.dart](file:///c:/Users/samad/Documents/LeadCityProjects/gradual/lib/features/quiz/quiz_result_cache_provider.dart) | L3, L33, L66 | ✅ Works — uses `localStorage` on web |

### 3.3 Device Features

| Feature | Found? | Notes |
|---------|--------|-------|
| Camera, Image/File picker | ❌ No | — |
| Location, Bluetooth, Sensors | ❌ No | — |
| Biometrics, Contacts | ❌ No | — |
| Background tasks | ❌ No | — |
| Permissions API | ❌ No | — |
| Deep links, Share, URL launcher | ❌ No | — |
| WebView, Maps, Ads, Payments | ❌ No | — |
| `SystemNavigator.pop()` | ⚠️ [daily_word_screen.dart](file:///c:/Users/samad/Documents/LeadCityProjects/gradual/lib/features/daily_word/daily_word_screen.dart#L56) L56 | **No-op on web** — does nothing in a browser, but won't crash |

### 3.4 Firebase Configuration

> [!CAUTION]
> **CRITICAL BLOCKER:** The Firebase web app has **not been registered**.

| Check | Status | Evidence |
|-------|--------|----------|
| `firebase_options.dart` web config | ❌ **Missing** | [firebase_options.dart](file:///c:/Users/samad/Documents/LeadCityProjects/gradual/lib/firebase_options.dart#L19-L24) L19–24: `if (kIsWeb) { throw UnsupportedError(...) }` |
| `firebase.json` web platform | ❌ **Missing** | [firebase.json](file:///c:/Users/samad/Documents/LeadCityProjects/gradual/firebase.json) only lists `android` platform |
| Firebase project web app | ❌ **Not registered** | No web `FirebaseOptions` (apiKey, authDomain, etc.) exist anywhere |

**Impact:** The app will **crash immediately** on web at startup. `main.dart` L11–12 calls `Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform)`, which throws `UnsupportedError` when `kIsWeb` is true.

### 3.5 Google Sign-In (Web)

| Check | Status | Evidence |
|-------|--------|----------|
| `google_sign_in_web` package | ✅ Resolved in lock file | — |
| Web OAuth client ID in `index.html` | ❌ **Missing** | No `web/` folder exists, so no `<meta name="google-signin-client_id">` tag |
| Google Cloud Console web client | UNVERIFIED | Need to check if a web OAuth client ID has been created for project `gradual-852ea` |

**Impact:** Google Sign-In will fail on web without the OAuth client ID meta tag.

### 3.6 Firebase Messaging (Web)

| Check | Status | Evidence |
|-------|--------|----------|
| VAPID key | ❌ **Missing** | No `getToken(vapidKey: ...)` call found |
| Service worker (`firebase-messaging-sw.js`) | ❌ **Missing** | No `web/` folder |
| Import in code | Present | [firebase_providers.dart](file:///c:/Users/samad/Documents/LeadCityProjects/gradual/lib/core/firebase/firebase_providers.dart#L18-L19) L18–19 |

**Impact:** Low — the `NotificationService` is currently a placeholder stub. FCM on web would require VAPID key + service worker, but since it's unused, this is non-blocking.

### 3.7 Hardcoded Secrets

| Secret | File | Line | Risk |
|--------|------|------|------|
| Firebase API Key `AIzaSyCaRYC82_NiCAzn3k00ULQlz6_pxHCxAWk` | [firebase_options.dart](file:///c:/Users/samad/Documents/LeadCityProjects/gradual/lib/firebase_options.dart#L56) | L56 | ⚠️ **Medium** — Firebase API keys are inherently public (used in JS SDK bundles too), but should be protected by Firebase Security Rules + App Check. This is standard practice, not a blocker. |
| `serviceAccountKey.json` | Project root | — | ⚠️ **Not in .gitignore!** `.gitignore` does not contain `serviceAccountKey.json`. If committed, this would be a **critical** security leak. Not a web-code issue, but flagged. |

---

## STEP 4: WEB READINESS

### 4.1 Responsive Design

| Check | Status | Evidence |
|-------|--------|----------|
| `LayoutBuilder` usage | ✅ Found | `streak_heatmap_widget.dart` L46 |
| `BoxConstraints(maxWidth)` | ✅ Found | `error_state_widget.dart` L19, `firestore_permission_widget.dart` L23, `placeholder_screen.dart` L23 |
| `MediaQuery` / `ScreenUtil` | ❌ Not used | No responsive breakpoint handling found |
| Fixed widths on main screens | ⚠️ **Risk** | Quiz, Profile, Daily Word screens use `EdgeInsets` and fixed padding (20px), which will look fine on mobile-width browsers but will stretch uncomfortably wide on desktop/tablet viewports with no `maxWidth` constraint |

**Impact:** Medium — the app will *function* on wide screens but will look stretched. A `ConstrainedBox(maxWidth: ~500)` wrapper on the main scaffold would fix this.

### 4.2 Routing & URL Strategy

| Check | Status | Evidence |
|-------|--------|----------|
| Router type | `MaterialApp.onGenerateRoute` | [app.dart](file:///c:/Users/samad/Documents/LeadCityProjects/gradual/lib/app.dart#L15) L15 |
| URL strategy | Hash (`/#/`) by default | No `usePathUrlStrategy()` call found |
| Deep link / refresh | ⚠️ **Limited** | `onGenerateRoute` handles named routes, so browser refresh on `/#/home` would work. However, state (e.g., quiz progress) would be lost on refresh since it's held in `StatefulWidget` state, not in the URL. |

### 4.3 Assets & Fonts

| Check | Status |
|-------|--------|
| `assets/` folder | Empty — `assets/images/` exists but contains **no files** |
| Fonts | Uses Material Design icons only (bundled with Flutter) |
| Local file paths | ❌ None found |

### 4.4 Performance Risks

| Risk | Severity | Notes |
|------|----------|-------|
| Large assets | ✅ None | No images or heavy assets |
| Heavy startup | ✅ Low | Firebase init is the only async work at startup |
| Large packages | ✅ Low | All packages are standard size; no ML/mapping libraries |
| WASM vs JS compilation | ℹ️ Note | Flutter 3.38 defaults to `canvaskit` renderer for web. Consider `--web-renderer html` for smaller initial load |

---

## STEP 5: BUILD TEST

### `flutter pub get`

Already resolved from prior runs. All dependencies resolve successfully — confirmed by the existence of `pubspec.lock` with web platform packages (`*_web` variants) resolved.

### `flutter analyze`

Last analyzed output showed **37 issues**, all of which are:
- `info` — `withOpacity` deprecation warnings (cosmetic, not blocking)
- `info` — `unnecessary_underscores` (lint, not blocking)
- `info` — `deprecated_member_use` (lint, not blocking)
- `warning` — Unused import `user_model.dart` in `daily_content_model.dart` L1

**Zero errors.** ✅

### `flutter build web`

> [!IMPORTANT]
> **Cannot run.** The `web/` folder does not exist. To add it, run:
> ```
> flutter create . --platforms web
> ```
> This will generate `web/index.html`, `web/manifest.json`, and `web/icons/`.
>
> Even after adding the `web/` folder, the build will **fail** because `firebase_options.dart` throws `UnsupportedError` when `kIsWeb` is true (L19–24). This must be fixed first by running `flutterfire configure` with the `--platforms=web` flag to register a Firebase web app and generate the web config.

---

## STEP 6: FINAL REPORT

### 1. Verdict

> **Ready with minor fixes** — Confidence: **High (85%)**

The codebase is remarkably clean for web migration. There are **zero** `dart:io` imports, **zero** platform channels, and **zero** device-specific API calls. Every pub dependency has a web-compatible counterpart already resolved. The only hard blocker is the missing Firebase web configuration, which is a one-time setup task.

### 2. Blockers Table

| # | Issue | File:Line | Severity | Proposed Fix | Effort |
|---|-------|-----------|----------|-------------|--------|
| 1 | **No `web/` folder** — project was never initialized for web | Project root | 🔴 Critical | Run `flutter create . --platforms web` | 5 min |
| 2 | **Firebase web app not registered** — `kIsWeb` throws `UnsupportedError` | [firebase_options.dart](file:///c:/Users/samad/Documents/LeadCityProjects/gradual/lib/firebase_options.dart#L19-L24) L19–24 | 🔴 Critical | Register a web app in Firebase Console, then run `flutterfire configure` to regenerate `firebase_options.dart` with web credentials | 15 min |
| 3 | **Google Sign-In missing web client ID** — no OAuth `<meta>` tag | `web/index.html` (doesn't exist) | 🔴 Critical | Create an OAuth 2.0 web client ID in Google Cloud Console, add `<meta name="google-signin-client_id" content="YOUR_ID.apps.googleusercontent.com">` to `index.html` | 15 min |
| 4 | **`serviceAccountKey.json` not in `.gitignore`** | [.gitignore](file:///c:/Users/samad/Documents/LeadCityProjects/gradual/.gitignore) | 🟡 High | Add `serviceAccountKey.json` to `.gitignore` immediately | 1 min |
| 5 | **`SystemNavigator.pop()` is a no-op on web** | [daily_word_screen.dart](file:///c:/Users/samad/Documents/LeadCityProjects/gradual/lib/features/daily_word/daily_word_screen.dart#L56) L56 | 🟢 Low | No-op on web; doesn't crash. Optionally guard with `if (!kIsWeb)` or remove the back-button intercept on web | 5 min |
| 6 | **No responsive max-width on main screens** | Multiple screen files | 🟡 Medium | Wrap main content in `Center > ConstrainedBox(maxWidth: 500)` for desktop viewports | 1 hr |
| 7 | **Hash-based URL strategy** | [app.dart](file:///c:/Users/samad/Documents/LeadCityProjects/gradual/lib/app.dart) | 🟢 Low | URLs will show as `/#/home` etc. Add `usePathUrlStrategy()` in `main.dart` if cleaner URLs are desired. Requires server-side SPA fallback config. | 10 min |
| 8 | **`flutter_native_splash` not configured for web** | [pubspec.yaml](file:///c:/Users/samad/Documents/LeadCityProjects/gradual/pubspec.yaml#L32-L37) L32–37 | 🟢 Low | Add `web: true` to `flutter_native_splash` config, or use CSS splash in `index.html` | 10 min |

### 3. Features That Will NOT Work on Web

| Feature | Why | Web Alternative |
|---------|-----|-----------------|
| `SystemNavigator.pop()` | Browser doesn't allow closing the tab programmatically | Remove or guard with `kIsWeb`; let browser handle back navigation |
| Push Notifications (FCM) | Placeholder only, but would need VAPID key + service worker + HTTPS | Web Push API via FCM with service worker, or skip for MVP |
| Native Splash Screen | `flutter_native_splash` generates native Android XML | Use CSS-based splash in `web/index.html` or enable the `web: true` flag |

### 4. Recommended Migration Plan

| Order | Task | Effort |
|-------|------|--------|
| 1 | Add `serviceAccountKey.json` to `.gitignore` | 1 min |
| 2 | Run `flutter create . --platforms web` to scaffold `web/` folder | 5 min |
| 3 | Go to Firebase Console → Project Settings → Add a **Web App** for `gradual-852ea` | 5 min |
| 4 | Run `flutterfire configure --platforms=web,android` to regenerate `firebase_options.dart` with web credentials | 10 min |
| 5 | Create a **Web** OAuth 2.0 Client ID in Google Cloud Console and add the `<meta>` tag to `web/index.html` | 15 min |
| 6 | Run `flutter build web` and verify it compiles | 5 min |
| 7 | Test Google Sign-In flow in Chrome | 10 min |
| 8 | Add `Center > ConstrainedBox(maxWidth: 500)` wrapper to main screens for desktop viewports | 1 hr |
| 9 | (Optional) Add `usePathUrlStrategy()` to `main.dart` for clean URLs | 10 min |
| 10 | Deploy to Firebase Hosting | 15 min |

**Total estimated effort: ~2.5 hours**

### 5. Deployment Recommendation

> [!TIP]
> **Firebase Hosting** is the natural choice since you're already using Firebase for Auth and Firestore.

| Host | Recommendation | Notes |
|------|---------------|-------|
| **Firebase Hosting** | ✅ **Recommended** | Already have `firebase.json` in the project. Add a `hosting` section pointing to `build/web`. Free SSL, global CDN, auto-deploys. |
| Vercel | ✅ Alternative | Works well with Flutter web SPA. Set `build/web` as output dir. |
| Netlify | ✅ Alternative | Same as Vercel. Add `_redirects` file for SPA routing. |
| GitHub Pages | ⚠️ Possible | Requires `--base-href=/gradual/` flag during build if not at root domain. |

**Firebase Hosting config to add to `firebase.json`:**
```json
{
  "hosting": {
    "public": "build/web",
    "ignore": ["firebase.json", "**/.*", "**/node_modules/**"],
    "rewrites": [
      { "source": "**", "destination": "/index.html" }
    ]
  }
}
```

**Deploy command:**
```bash
flutter build web --release
firebase deploy --only hosting
```

### 6. Questions Before Proceeding

1. **Do you want me to proceed with the migration steps?** (Steps 1–10 above)
2. **Do you want clean URLs** (`/home`, `/quiz`) or are hash URLs (`/#/home`, `/#/quiz`) acceptable?
3. **Is the `serviceAccountKey.json` file currently committed to your Git repository?** If yes, you need to rotate the key immediately after removing it.
4. **Do you plan to support mobile AND web simultaneously**, or is this a full pivot to web-only?
5. **Do you want the web app to be responsive for desktop/tablet**, or is mobile-browser-only acceptable for now?
