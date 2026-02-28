# Auth Setup (Email + Google)

This project now has:

- Local email/password registration and sign-in (stored in app preferences)
- Google sign-in via `google_sign_in` (v7 API)

## 1) Google OAuth configuration

Follow Google Identity setup for each platform:

- Android: create an Android OAuth client in Google Cloud Console
  - Package name: `com.gico.stepped`
  - Add SHA-1 and SHA-256 fingerprints
- Also create a Web OAuth client and use its client ID as `serverClientId`

References:

- [Flutter `google_sign_in` package docs](https://pub.dev/packages/google_sign_in)
- [Google Identity for Android](https://developer.android.com/identity/sign-in/credential-manager-siwg)

## 2) Pass server client ID to Flutter

Build/run with:

```bash
copy google_sign_in.env.example.json google_sign_in.env.json
# edit google_sign_in.env.json and set GOOGLE_SERVER_CLIENT_ID
flutter run --dart-define-from-file=google_sign_in.env.json
```

The app reads this value from `String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID')`.
