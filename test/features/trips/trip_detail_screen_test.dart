import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:stepped/data/db/app_db.dart';
import 'package:stepped/data/repositories/trips_repository.dart';
import 'package:stepped/features/trips/trip_detail_screen.dart';

void main() {
  testWidgets('trip detail screen opens in read-only mode by default', (
    tester,
  ) async {
    const trip = TripRecord(
      id: 11,
      countryCode: 'US',
      countryName: 'United States of America',
      startDate: 1787184000000,
      endDate: 1788134400000,
      cities: 'New York, Washington D.C.',
      notes: 'Summer route',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          tripByIdProvider(11).overrideWith((ref) async => trip),
        ],
        child: const MaterialApp(
          home: TripDetailScreen(tripId: 11),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Trip'), findsOneWidget);
    expect(find.text('Route details'), findsOneWidget);
    expect(find.text('Update Trip'), findsNothing);
    expect(find.text('Destination'), findsOneWidget);
  });
}
