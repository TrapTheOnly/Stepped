import '../../data/db/app_db.dart';

int totalTripDays(List<TripRecord> trips) {
  return trips.fold<int>(0, (sum, trip) {
    final start = DateTime.fromMillisecondsSinceEpoch(trip.startDate);
    final end = DateTime.fromMillisecondsSinceEpoch(trip.endDate);
    final days = end.difference(start).inDays + 1;
    return sum + (days < 1 ? 1 : days);
  });
}

int uniqueCitiesCount(List<TripRecord> trips) {
  final cities = <String>{};
  for (final trip in trips) {
    final parts = trip.cities.split(',');
    for (final part in parts) {
      final city = part.trim().toLowerCase();
      if (city.isNotEmpty) {
        cities.add(city);
      }
    }
  }
  return cities.length;
}

List<MapEntry<String, int>> topCountries(List<TripRecord> trips) {
  final counts = <String, int>{};
  for (final trip in trips) {
    counts[trip.countryName] = (counts[trip.countryName] ?? 0) + 1;
  }
  final sorted = counts.entries.toList(growable: false)
    ..sort((a, b) => b.value.compareTo(a.value));
  if (sorted.length <= 5) {
    return sorted;
  }
  return sorted.take(5).toList(growable: false);
}

List<MapEntry<int, int>> yearlyTrips(List<TripRecord> trips) {
  final counts = <int, int>{};
  for (final trip in trips) {
    final year = DateTime.fromMillisecondsSinceEpoch(trip.startDate).year;
    counts[year] = (counts[year] ?? 0) + 1;
  }
  final sorted = counts.entries.toList(growable: false)
    ..sort((a, b) => b.key.compareTo(a.key));
  return sorted;
}
