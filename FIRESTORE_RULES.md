# Firestore Security Rules

Copy the rules below into **Firebase Console** → your project (`gradual-852ea`) → **Firestore** → **Rules** → **Publish**.

Or deploy from this repo:

```bash
firebase deploy --only firestore:rules
```

## Rules (also in `firestore.rules`)

```
rules_version = '2';

service cloud.firestore {
  match /databases/{database}/documents {

    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }

    match /{collectionId}/{docId} {
      allow read: if request.auth != null
        && (collectionId.matches('content_.*') || collectionId.matches('quizzes_.*'));
      allow write: if false;
    }
  }
}
```

## What this allows

| Path | Access |
|------|--------|
| `users/{uid}` | Read/write only when `request.auth.uid == uid` |
| `content_software_engineering/{date}` | Read for any signed-in user |
| `quizzes_software_engineering/{date}` | Read for any signed-in user |

Content and quiz documents are **read-only** from the app (writes go through Admin SDK / import script).

## After publishing

1. Sign out and sign back in so the auth token refreshes.
2. Cold-restart the app (`flutter run`).

If you still see "Access denied", confirm you are logged in and the document path matches your user's `field_of_study` (default: `software_engineering` → collection `content_software_engineering`).
