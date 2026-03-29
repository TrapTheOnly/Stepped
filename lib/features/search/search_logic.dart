import '../../data/db/app_db.dart';
import '../map/globe/globe_country_data.dart';
import 'search_models.dart';

List<CountrySearchEntry> buildCountrySearchCatalog({
  required List<GlobeCountryShape> datasetCountries,
  required List<TripRecord> trips,
  required List<CountryVisitRecord> visits,
}) {
  final visitedSet = <String>{
    for (final visit in visits) visit.countryCode.toUpperCase(),
  };

  final tripsByCode = <String, List<TripRecord>>{};
  for (final trip in trips) {
    final code = trip.countryCode.toUpperCase();
    tripsByCode.putIfAbsent(code, () => <TripRecord>[]).add(trip);
  }

  final refs = <SearchCountryRef>[
    for (final country in datasetCountries)
      SearchCountryRef(
        iso2: country.iso2,
        name: country.name,
        continent: country.continent,
        focusableOnGlobe: true,
      ),
    ...microstateSearchOnly,
  ];

  return refs.map(
    (refItem) {
      final tripsForCountry =
          tripsByCode[refItem.iso2.toUpperCase()] ?? const <TripRecord>[];
      final latestTripId = tripsForCountry
          .where((trip) => trip.id != null)
          .map((trip) => trip.id!)
          .firstOrNull;

      return CountrySearchEntry(
        iso2: refItem.iso2,
        name: refItem.name,
        continent: refItem.continent,
        focusableOnGlobe: refItem.focusableOnGlobe,
        visited: visitedSet.contains(refItem.iso2.toUpperCase()),
        tripCount: tripsForCountry.length,
        latestTripId: latestTripId,
      );
    },
  ).toList(growable: false);
}

List<CountrySearchEntry> buildCountrySearchResults({
  required String query,
  required List<GlobeCountryShape> datasetCountries,
  required List<TripRecord> trips,
  required List<CountryVisitRecord> visits,
}) {
  final catalog = buildCountrySearchCatalog(
    datasetCountries: datasetCountries,
    trips: trips,
    visits: visits,
  );
  final q = query.trim().toLowerCase();
  final filtered = <CountrySearchEntry>[];

  for (final entry in catalog) {
    final iso2Lower = entry.iso2.toLowerCase();
    final nameLower = entry.name.toLowerCase();
    if (q.isNotEmpty && !nameLower.contains(q) && !iso2Lower.contains(q)) {
      continue;
    }
    filtered.add(entry);
  }

  filtered.sort((left, right) {
    final leftRank = searchRank(left, q);
    final rightRank = searchRank(right, q);
    if (leftRank != rightRank) {
      return leftRank.compareTo(rightRank);
    }
    if (left.visited != right.visited) {
      return left.visited ? -1 : 1;
    }
    if (left.tripCount != right.tripCount) {
      return right.tripCount.compareTo(left.tripCount);
    }
    return left.name.compareTo(right.name);
  });

  final maxResults = q.isEmpty ? 120 : 200;
  if (filtered.length <= maxResults) {
    return filtered;
  }
  return filtered.take(maxResults).toList(growable: false);
}

int searchRank(CountrySearchEntry entry, String query) {
  if (query.isEmpty) {
    return 5;
  }

  final name = entry.name.toLowerCase();
  final iso2 = entry.iso2.toLowerCase();

  if (name == query || iso2 == query) {
    return 0;
  }
  if (name.startsWith(query) || iso2.startsWith(query)) {
    return 1;
  }
  return 2;
}
