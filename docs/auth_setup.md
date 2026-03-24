# Auth Setup (Firebase Auth)

This project now signs users into Firebase Auth on the client, then uses the backend to validate the Firebase ID token and return a normalized user payload.

App endpoints:

- `GET /v1/auth/me`

## 1) Firebase app configuration

This app now needs a Firebase Android app for package `com.gico.stepped`.

Current Firebase project:

- Project ID: `stepped-488711`
- Android package: `com.gico.stepped`

Required:

- `android/app/google-services.json`
- SHA-1 and SHA-256 fingerprints added to the Firebase Android app
- Google sign-in enabled in Firebase Console -> Authentication -> Sign-in method

The backend still needs:

- `FIREBASE_WEB_API_KEY`

References:

- [FlutterFire setup docs](https://firebase.google.com/docs/flutter/setup)
- [Firebase Auth for Flutter](https://firebase.google.com/docs/auth/flutter/start)

## 2) Flutter runtime defines

```bash
copy google_sign_in.env.example.json google_sign_in.env.json
# set GOOGLE_SERVER_CLIENT_ID only if you need to override the web client id
# optional: STEPPED_API_BASE_URL, GEMINI_MODEL, GEMINI_API_VERSION
flutter run --dart-define-from-file=google_sign_in.env.json
```

Used in app:

- `GOOGLE_SERVER_CLIENT_ID`: optional override for Google sign-in web client id
- `STEPPED_API_BASE_URL`: auth API base URL (defaults to `https://api.stepped.world`)
- `GEMINI_MODEL`: local Gemini planner model preference (defaults to `gemini-3-flash`)
- `GEMINI_API_VERSION`: Gemini REST API version for local planner (defaults to `v1beta`)

## 3) Backend auth environment

Set these in your API deployment:

- `FIREBASE_WEB_API_KEY`: Firebase project's Web API key
- `GEMINI_API_KEY`: Gemini server key (for AI trip plan endpoint)

Notes:

- The Flutter app uses `firebase_auth` for email/password and Google sign-in.
- The backend currently validates Firebase tokens through `/v1/auth/me`.
- `GOOGLE_SERVER_CLIENT_ID` is optional if the Android Firebase config already provides the needed web client id.

Health check:

- `GET /v1/auth/health` returns whether auth is configured.
