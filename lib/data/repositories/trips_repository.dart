import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../db/app_db.dart';

final tripsRepositoryProvider = Provider<TripsRepository>((ref) {
  return TripsRepository(ref.watch(databaseProvider));
});

final tripsStreamProvider = StreamProvider<List<TripRecord>>((ref) {
  return ref.watch(tripsRepositoryProvider).watchTrips();
});

final tripByIdProvider = FutureProvider.family<TripRecord?, int>((ref, id) {
  return ref.watch(tripsRepositoryProvider).getTripById(id);
});

class TripsRepository {
  const TripsRepository(this._database);

  final AppDatabase _database;

  Stream<List<TripRecord>> watchTrips() {
    return _database.watchTripsOrderedByStartDesc();
  }

  Future<List<TripRecord>> getRecentTrips({int limit = 6}) {
    return _database.getRecentTrips(limit);
  }

  Future<TripRecord?> getTripById(int id) {
    return _database.getTripById(id);
  }

  Future<int> addTrip(TripRecord trip) {
    return _database.insertTrip(trip);
  }

  Future<void> updateTrip(TripRecord trip) {
    return _database.updateTrip(trip);
  }

  Future<void> replaceTrips(List<TripRecord> trips) {
    return _database.replaceTrips(trips);
  }

  Future<void> deleteTrip(int id) {
    return _database.deleteTrip(id);
  }
}
