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
- `google_sign_in`

## Run

1. Install Flutter stable and Android SDK.
2. In this project root, run:

```bash
flutter pub get
copy google_sign_in.env.example.json google_sign_in.env.json
# then edit google_sign_in.env.json:
# - GOOGLE_SERVER_CLIENT_ID
# - STEPPED_API_BASE_URL (optional; default is https://api.stepped.world)
# - GEMINI_MODEL (optional; default is gemini-3-flash)
# - GEMINI_API_VERSION (optional; default is v1beta)
flutter run --dart-define-from-file=google_sign_in.env.json
```

For OAuth setup details, see [docs/auth_setup.md](docs/auth_setup.md).

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
