import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../db/app_db.dart';

final visitsRepositoryProvider = Provider<VisitsRepository>((ref) {
  return VisitsRepository(ref.watch(databaseProvider));
});

final visitedCountProvider = StreamProvider<int>((ref) {
  return ref.watch(visitsRepositoryProvider).watchVisitedCount();
});

final visitedCountriesProvider =
    StreamProvider<List<CountryVisitRecord>>((ref) {
  return ref.watch(visitsRepositoryProvider).watchVisitedCountries();
});

class VisitsRepository {
  const VisitsRepository(this._database);

  final AppDatabase _database;

  Stream<int> watchVisitedCount() {
    return _database.watchVisitedCount();
  }

  Stream<List<CountryVisitRecord>> watchVisitedCountries() {
    return _database.watchVisitedCountries();
  }

  Future<int> getVisitedCount() {
    return _database.getVisitedCount();
  }

  Future<List<CountryVisitRecord>> getVisitedCountries() {
    return _database.getVisitedCountriesOrderedByName();
  }

  Future<void> upsertVisitIfAbsent({
    required String countryCode,
    required String countryName,
    required int visitedAt,
  }) {
    return _database.upsertVisitIfAbsent(
      countryCode: countryCode,
      countryName: countryName,
      visitedAt: visitedAt,
    );
  }

  Future<void> upsertVisit({
    required String countryCode,
    required String countryName,
    required int visitedAt,
  }) {
    return _database.upsertVisit(
      countryCode: countryCode,
      countryName: countryName,
      visitedAt: visitedAt,
    );
  }

  Future<void> deleteVisitByCountryCode(String countryCode) {
    return _database.deleteVisitByCountryCode(countryCode);
  }

  Future<void> setVisited({
    required String countryCode,
    required String countryName,
    required bool visited,
  }) {
    if (visited) {
      return upsertVisit(
        countryCode: countryCode,
        countryName: countryName,
        visitedAt: DateTime.now().millisecondsSinceEpoch,
      );
    }

    return deleteVisitByCountryCode(countryCode);
  }
}
