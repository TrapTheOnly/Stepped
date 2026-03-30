import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/db/app_db.dart';
import '../../data/repositories/trips_repository.dart';
import '../social/social_state.dart';

final addTripControllerProvider =
    AutoDisposeAsyncNotifierProvider<AddTripController, void>(
  AddTripController.new,
);

class AddTripController extends AutoDisposeAsyncNotifier<void> {
  late final TripsRepository _repository;

  @override
  FutureOr<void> build() {
    _repository = ref.read(tripsRepositoryProvider);
  }

  Future<bool> submit({
    int? tripId,
    required String countryCode,
    required String countryName,
    required DateTime startDate,
    required DateTime endDate,
    required String cities,
    int? sourceWishlistItemId,
    String? cityDataJson,
    String? coverImageUri,
    String? notes,
  }) async {
    if (countryCode.trim().isEmpty ||
        countryName.trim().isEmpty ||
        cities.trim().isEmpty) {
      state = AsyncValue.error(
        ArgumentError('Country and cities are required.'),
        StackTrace.current,
      );
      return false;
    }

    if (endDate.isBefore(startDate)) {
      state = AsyncValue.error(
        ArgumentError('End date cannot be before start date.'),
        StackTrace.current,
      );
      return false;
    }

    state = const AsyncLoading();
    final trip = TripRecord(
      id: tripId,
      countryCode: countryCode.trim().toUpperCase(),
      countryName: countryName.trim(),
      startDate: startDate.millisecondsSinceEpoch,
      endDate: endDate.millisecondsSinceEpoch,
      cities: cities.trim(),
      sourceWishlistItemId: sourceWishlistItemId,
      cityDataJson: _nullableTrim(cityDataJson),
      coverImageUri: _nullableTrim(coverImageUri),
      notes: _nullableTrim(notes),
    );

    try {
      if (tripId == null) {
        await _repository.addTrip(trip);
      } else {
        await _repository.updateTrip(trip);
      }
      await ref.read(socialSyncControllerProvider).flushTravelNow();
      state = const AsyncData(null);
      return true;
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
      return false;
    }
  }

  String? _nullableTrim(String? value) {
    if (value == null) {
      return null;
    }
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}
