# Stepped (Flutter)

Minimal Android-first travel tracking UI built with Material 3 and Material You dynamic color.

## Features

- Material 3 with dynamic color on Android 12+
- Bottom navigation with tabs: Map, Trips, Wishlist, Profile
- Hero globe card with custom `CustomPainter` and drag-to-rotate interaction
- Real country boundaries loaded from GeoJSON (`assets/data/countries.geojson`)
- Countries visited pill, two progress rows, three primary actions
- Horizontal recent trips carousel
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

## Run

1. Install Flutter stable and Android SDK.
2. In this project root, run:

```bash
flutter pub get
flutter run
```

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

