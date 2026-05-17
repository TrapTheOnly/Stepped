import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/trips_repository.dart';
import '../../data/repositories/visits_repository.dart';
import '../../domain/models/trip_ui.dart';
import '../social/social_state.dart';
import 'globe/globe_country_data.dart';

const totalCountriesInWorld = 195;
const totalContinentsInWorld = 7;
const _continentDisplayOrder = <String>[
  'Africa',
  'Asia',
  'Europe',
  'North America',
  'South America',
  'Oceania',
  'Antarctica',
];

class GlobeFocusRequest {
  const GlobeFocusRequest({
    required this.countryCode,
    required this.token,
  });

  final String countryCode;
  final int token;
}

final globeFocusRequestProvider =
    StateProvider<GlobeFocusRequest?>((ref) => null);

final globeResetRequestProvider = StateProvider<int?>((ref) => null);

class ContinentProgress {
  const ContinentProgress({
    required this.continent,
    required this.visitedCount,
    required this.totalCount,
  });

  final String continent;
  final int visitedCount;
  final int totalCount;

  double get progress =>
      totalCount == 0 ? 0 : (visitedCount / totalCount).clamp(0, 1);
}

class MapDashboardState {
  const MapDashboardState({
    required this.visitedCount,
    required this.totalTrips,
    required this.recentTrips,
    required this.continentsVisited,
    required this.worldVisited,
    required this.visitedCountryCodes,
    required this.continentProgress,
  });

  final int visitedCount;
  final int totalTrips;
  final List<TripUi> recentTrips;
  final int continentsVisited;
  final int worldVisited;
  final List<String> visitedCountryCodes;
  final List<ContinentProgress> continentProgress;
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
  final totalTrips = trips.length;
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

  final continentTotals = <String, int>{
    for (final continent in _continentDisplayOrder) continent: 0,
  };
  for (final continent in continentByCountryCode.values) {
    if (!continentTotals.containsKey(continent)) {
      continue;
    }
    continentTotals[continent] = continentTotals[continent]! + 1;
  }

  for (final entry in _hiddenMicrostatesByContinent.entries) {
    final current = continentTotals[entry.key] ?? 0;
    continentTotals[entry.key] = current + entry.value;
  }

  final continentVisited = <String, int>{
    for (final continent in _continentDisplayOrder) continent: 0,
  };
  for (final countryCode in visitedCountryCodes) {
    final continent = continentByCountryCode[countryCode];
    if (continent == null || !continentVisited.containsKey(continent)) {
      continue;
    }
    continentVisited[continent] = continentVisited[continent]! + 1;
  }

  final continentProgress = _continentDisplayOrder
      .map(
        (continent) => ContinentProgress(
          continent: continent,
          visitedCount: continentVisited[continent] ?? 0,
          totalCount: continentTotals[continent] ?? 0,
        ),
      )
      .toList(growable: false);

  final visitedCountryCodesSorted = visitedCountryCodes.toList(growable: false)
    ..sort();

  return AsyncValue.data(
    MapDashboardState(
      visitedCount: visitedCount,
      totalTrips: totalTrips,
      recentTrips: recentTrips,
      continentsVisited: continentsVisited,
      worldVisited: visitedCount,
      visitedCountryCodes: visitedCountryCodesSorted,
      continentProgress: continentProgress,
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
      await ref.read(socialSyncControllerProvider).flushTravelNow();
      state = const AsyncData(null);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }
}

const _continentByCountryCode = <String, String>{
  'AD': 'Europe',
  'JP': 'Asia',
  'IT': 'Europe',
  'LI': 'Europe',
  'MC': 'Europe',
  'SM': 'Europe',
  'TR': 'Asia',
  'AE': 'Asia',
  'US': 'North America',
  'VA': 'Europe',
  'BR': 'South America',
  'AU': 'Oceania',
  'ZA': 'Africa',
  'AQ': 'Antarctica',
};

const _hiddenMicrostatesByContinent = <String, int>{
  'Europe': 5,
};
