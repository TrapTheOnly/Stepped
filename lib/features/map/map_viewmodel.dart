import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/trips_repository.dart';
import '../../data/repositories/visits_repository.dart';
import '../../domain/models/trip_ui.dart';
import 'globe/globe_country_data.dart';

const totalCountriesInWorld = 195;
const totalContinentsInWorld = 7;

class MapDashboardState {
  const MapDashboardState({
    required this.visitedCount,
    required this.recentTrips,
    required this.continentsVisited,
    required this.worldVisited,
    required this.visitedCountryCodes,
  });

  final int visitedCount;
  final List<TripUi> recentTrips;
  final int continentsVisited;
  final int worldVisited;
  final List<String> visitedCountryCodes;
}

final mapDashboardProvider = Provider<AsyncValue<MapDashboardState>>((ref) {
  final visitedCountriesAsync = ref.watch(visitedCountriesProvider);
  final tripsAsync = ref.watch(tripsStreamProvider);
  final globeDatasetAsync = ref.watch(globeCountryDatasetProvider);

  if (visitedCountriesAsync.hasError) {
    return AsyncValue.error(
      visitedCountriesAsync.error!,
      visitedCountriesAsync.stackTrace ?? StackTrace.current,
    );
  }

  if (tripsAsync.hasError) {
    return AsyncValue.error(
      tripsAsync.error!,
      tripsAsync.stackTrace ?? StackTrace.current,
    );
  }

  if (globeDatasetAsync.hasError) {
    return AsyncValue.error(
      globeDatasetAsync.error!,
      globeDatasetAsync.stackTrace ?? StackTrace.current,
    );
  }

  final visits = visitedCountriesAsync.valueOrNull;
  final trips = tripsAsync.valueOrNull;
  final globeDataset = globeDatasetAsync.valueOrNull;
  if (visits == null || trips == null || globeDataset == null) {
    return const AsyncValue.loading();
  }

  final visitedCountryCodes =
      visits.map((visit) => visit.countryCode.toUpperCase()).toSet();
  final visitedCount = visitedCountryCodes.length;
  final recentTrips =
      trips.take(6).map(TripUi.fromRecord).toList(growable: false);

  final continentByCountryCode = <String, String>{
    for (final entry in globeDataset.byIso2.entries)
      if (entry.value.continent != null) entry.key: entry.value.continent!,
    ..._continentByCountryCode,
  };

  final continentsVisited = visitedCountryCodes
      .map((code) => continentByCountryCode[code])
      .whereType<String>()
      .toSet()
      .length;

  final visitedCountryCodesSorted = visitedCountryCodes.toList(growable: false)
    ..sort();

  return AsyncValue.data(
    MapDashboardState(
      visitedCount: visitedCount,
      recentTrips: recentTrips,
      continentsVisited: continentsVisited,
      worldVisited: visitedCount,
      visitedCountryCodes: visitedCountryCodesSorted,
    ),
  );
});

final globeCountryDatasetProvider = FutureProvider<GlobeCountryDataset>((ref) {
  return GlobeCountryDatasetLoader.load();
});

final mapVisitToggleControllerProvider =
    AutoDisposeAsyncNotifierProvider<MapVisitToggleController, void>(
  MapVisitToggleController.new,
);

class MapVisitToggleController extends AutoDisposeAsyncNotifier<void> {
  late final VisitsRepository _repository;

  @override
  FutureOr<void> build() {
    _repository = ref.read(visitsRepositoryProvider);
  }

  Future<void> setVisited({
    required String countryCode,
    required String countryName,
    required bool visited,
  }) async {
    state = const AsyncLoading();
    try {
      await _repository.setVisited(
        countryCode: countryCode,
        countryName: countryName,
        visited: visited,
      );
      state = const AsyncData(null);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }
}

const _continentByCountryCode = <String, String>{
  'JP': 'Asia',
  'IT': 'Europe',
  'TR': 'Asia',
  'AE': 'Asia',
  'US': 'North America',
  'BR': 'South America',
  'AU': 'Oceania',
  'ZA': 'Africa',
  'AQ': 'Antarctica',
};
