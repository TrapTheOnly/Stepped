import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:stepped/data/db/app_db.dart';
import 'package:stepped/features/map/globe/globe_country_data.dart';
import 'package:stepped/features/map/map_viewmodel.dart';
import 'package:stepped/features/trips/add_trip_controller.dart';
import 'package:stepped/features/trips/add_trip_screen.dart';
import 'package:stepped/data/repositories/trips_repository.dart';
import 'package:stepped/features/trips/widgets/add_trip_destination_preview.dart';

void main() {
  testWidgets('edit trip screen renders form content', (tester) async {
    final country = GlobeCountryShape(
      iso2: 'TR',
      name: 'Turkey',
      continent: 'Asia',
      lodRings: const <List<GlobeRingShape>>[
        <GlobeRingShape>[],
        <GlobeRingShape>[],
      ],
      centroid: GlobeGeoPoint(lon: 0, lat: 0),
      maxAngularDistanceRad: 0,
    );
    final dataset = GlobeCountryDataset(
      countries: <GlobeCountryShape>[country],
      byIso2: <String, GlobeCountryShape>{'TR': country},
    );
    const trip = TripRecord(
      id: 7,
      countryCode: 'TR',
      countryName: 'Turkey',
      startDate: 1704067200000,
      endDate: 1704326400000,
      cities: 'Istanbul, Ankara',
      notes: 'Test notes',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          globeCountryDatasetProvider.overrideWith((ref) async => dataset),
          tripByIdProvider(7).overrideWith((ref) async => trip),
          addTripControllerProvider.overrideWith(_TestAddTripController.new),
        ],
        child: const MaterialApp(
          home: AddTripScreen(tripId: 7),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Edit Trip'), findsOneWidget);
    expect(find.text('Update Trip'), findsOneWidget);
    expect(find.text('Destination'), findsOneWidget);
    expect(find.byType(AddTripDestinationPreview), findsOneWidget);
    expect(tester.getCenter(find.text('Update Trip')).dy, greaterThan(500));
  });
}

class _TestAddTripController extends AddTripController {
  @override
  FutureOr<void> build() {}
}
