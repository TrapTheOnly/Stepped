# Auth Setup (Firebase Email + Google)

This project now uses centralized auth against your cloud API.

App endpoints:

- `POST /v1/auth/register`
- `POST /v1/auth/sign-in`
- `POST /v1/auth/google`
- `GET /v1/auth/me`

## 1) Google OAuth configuration

Create OAuth clients in Google Cloud Console:

- Android OAuth client
  - Package: `com.gico.stepped`
  - Add SHA-1 and SHA-256 (debug + release keys)
- Web OAuth client
  - Use this client ID as `GOOGLE_SERVER_CLIENT_ID`

References:

- [Flutter `google_sign_in` package docs](https://pub.dev/packages/google_sign_in)
- [Google Identity for Android](https://developer.android.com/identity/sign-in/credential-manager-siwg)

## 2) Flutter runtime defines

```bash
copy google_sign_in.env.example.json google_sign_in.env.json
# set GOOGLE_SERVER_CLIENT_ID
# optional: STEPPED_API_BASE_URL, GEMINI_MODEL, GEMINI_API_VERSION
flutter run --dart-define-from-file=google_sign_in.env.json
```

Used in app:

- `GOOGLE_SERVER_CLIENT_ID`: Google mobile sign-in setup
- `STEPPED_API_BASE_URL`: auth API base URL (defaults to `https://api.stepped.world`)
- `GEMINI_MODEL`: local Gemini planner model preference (defaults to `gemini-3-flash`)
- `GEMINI_API_VERSION`: Gemini REST API version for local planner (defaults to `v1beta`)

## 3) Backend auth environment

Set these in your API deployment:

- `FIREBASE_WEB_API_KEY`: Firebase project's Web API key
- `GEMINI_API_KEY`: Gemini server key (for AI trip plan endpoint)

Notes:

- Backend `/v1/auth/*` now uses Firebase Identity Toolkit.
- `GOOGLE_SERVER_CLIENT_ID` is still required in the Flutter app for the Google account picker flow.

Health check:

- `GET /v1/auth/health` returns whether auth is configured.
