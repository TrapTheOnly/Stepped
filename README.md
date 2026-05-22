# Stepped

Minimal Android-first travel tracking UI built with Material 3 and Material You dynamic color.

## Features

- Material 3 with dynamic color on Android 12+
- Bottom navigation with tabs: Map, Trips, Wishlist, Profile
- Hero globe card with custom `CustomPainter` and drag-to-rotate interaction
- Real country boundaries loaded from GeoJSON (`assets/data/countries.geojson`)
- Countries visited pill, two progress rows, three primary actions
- Horizontal recent trips carousel
- Animated auth entry flow (Sign in / Register + Google sign-in)
- Local persistence with `sqflite` (trips, country visits, wishlist)
- Riverpod state management + `go_router` navigation
- Seeded first-run data (Japan, Italy, Turkey, UAE)

## Stack

- Flutter + Dart
- `flutter_riverpod`
- `go_router`
- `dynamic_color`
- `sqflite`
- `cached_network_image`
- `firebase_core`
- `firebase_auth`
- `google_sign_in`

## Run

1. Install Flutter stable and Android SDK.
2. In this project root, run:

```bash
flutter pub get
copy google_sign_in.env.example.json google_sign_in.env.json
# then edit google_sign_in.env.json:
# - GOOGLE_SERVER_CLIENT_ID (optional if google-services.json already matches your Firebase project)
# - STEPPED_API_BASE_URL (optional; default is https://api.stepped.world)
# - GEMINI_MODEL (optional; default is gemini-3-flash)
# - GEMINI_API_VERSION (optional; default is v1beta)
flutter run --dart-define-from-file=google_sign_in.env.json
```

This app now signs users into Firebase Auth first, then calls the backend with the Firebase ID token.

For Firebase/Auth setup details, see [docs/auth_setup.md](docs/auth_setup.md).

## Friend Invite Links

- Android app links are configured for `https://app.stepped.world/friends/add/:token`.
- Android custom-scheme links are configured for `stepped://friends/add/:token`.
- Both link types resolve to the existing in-app route `/friends/add/:token`, and unauthenticated users are redirected through `/auth` before returning to the invite route.
- If an iOS target is added later, enable the Associated Domains capability with `applinks:app.stepped.world` and host an `apple-app-site-association` file on `app.stepped.world` that allows `/friends/add/*` for the app's team ID and bundle ID.

## CI APK Release

- Workflow: `.github/workflows/android-apk-release.yml`
- Trigger: every push to `main` and manual run from Actions tab
- Output: release APK attached to a new GitHub Release and also uploaded as a workflow artifact

Required GitHub Actions value:

- Environment: `Main`
- Key: `GOOGLE_SERVER_CLIENT_ID`
- Location: `Settings -> Environments -> Main -> Variables` (or `Secrets`)
- Optional key: `STEPPED_API_BASE_URL` (if you build against a non-default API host)
- Optional key: `GEMINI_MODEL` (fallback: `gemini-3-flash`)
- Optional key: `GEMINI_API_VERSION` (fallback: `v1beta`)

## CI iOS TestFlight

- Workflow: `.github/workflows/ios-testflight.yml`
- Trigger: every push to `main` that touches app/iOS files, plus manual run from Actions tab
- Output: signed App Store IPA uploaded as a workflow artifact and pushed to App Store Connect/TestFlight with fastlane
- Runner: GitHub-hosted `macos-15`

Required GitHub Actions values in environment `Main`:

- Secret: `APP_STORE_CONNECT_KEY_ID`
- Secret: `APP_STORE_CONNECT_ISSUER_ID`
- Secret: `APP_STORE_CONNECT_API_KEY_BASE64` (base64 of `AuthKey_<KEY_ID>.p8`)
- Secret: `IOS_DISTRIBUTION_CERTIFICATE_BASE64` (base64 of the Apple Distribution `.p12`)
- Secret: `IOS_DISTRIBUTION_CERTIFICATE_PASSWORD`
- Secret: `IOS_PROVISIONING_PROFILE_BASE64` (base64 of the App Store `.mobileprovision` for `com.gico.stepped`)
- Secret: `GOOGLE_SERVER_CLIENT_ID`
- Optional variable: `IOS_BUILD_NUMBER_OFFSET` (defaults to `1000`; increase if App Store Connect already has a higher build number for the current app version)
- Optional variable: `IOS_USES_NON_EXEMPT_ENCRYPTION` (`true` or `false`, if you want fastlane to set export-compliance metadata during upload)
- Optional variables: `STEPPED_API_BASE_URL`, `GEMINI_MODEL`, `GEMINI_API_VERSION`

Base64 helpers:

```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("AuthKey_XXXXXXXXXX.p8")) | Set-Clipboard
[Convert]::ToBase64String([IO.File]::ReadAllBytes("AppleDistribution.p12")) | Set-Clipboard
[Convert]::ToBase64String([IO.File]::ReadAllBytes("Stepped_App_Store.mobileprovision")) | Set-Clipboard
```

## CI iOS Archive

- Workflow source: Xcode Cloud in App Store Connect, not GitHub Actions
- GitHub check names such as `stepped | Default | Archive - iOS` are mirrored back from Xcode Cloud after Apple runs the archive workflow against this repository
- Bootstrap script: `ios/ci_scripts/ci_post_clone.sh`
- TestFlight deployment from GitHub Actions is handled separately by `.github/workflows/ios-testflight.yml`

Why the archive was failing:

- `ios/Flutter/Release.xcconfig` includes `Generated.xcconfig`, but `ios/.gitignore` intentionally excludes `Flutter/Generated.xcconfig`
- CocoaPods support files under `ios/Pods/Target Support Files/...` are also intentionally excluded from git
- Xcode Cloud checks out a clean copy of the repo, so a Flutter app must run `flutter pub get` and `pod install` before Xcode tries to archive it

The post-clone script now does exactly that for Xcode Cloud:

- installs Flutter stable
- runs `flutter precache --ios`
- runs `flutter pub get`
- runs `pod install` inside `ios/`

## CI Backend Deploy

- Workflow: `.github/workflows/backend-cloud-run-deploy.yml`
- Trigger: pushes touching `backend/**` on `main`, plus manual run
- Deploy target: Google Cloud Run (`stepped-cloud-api` by default)
- Auth in CI: `GCP_WORKLOAD_IDENTITY_PROVIDER` + `GCP_SERVICE_ACCOUNT` (preferred), or `GCP_SA_KEY_JSON` fallback
- Full backend CI variable list: see [backend/README.md](backend/README.md)

## Dynamic Color

- On Android 12+ (API 31+), the app reads system dynamic colors via `dynamic_color`.
- On older Android versions, a fallback seed-based `ColorScheme` is used.
- Material 3 is enabled with `ThemeData(useMaterial3: true)`.

## Notes

- Initial seed data runs once using a SharedPreferences flag (`stepped_seed_v1`).
- Trips support create, read, update, and delete.
- Wishlist supports create, read, update, and delete.
- Adding/updating a trip upserts a country visit if it does not already exist.
- Country geometry source: https://github.com/datasets/geo-countries
