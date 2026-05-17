class CountrySearchEntry {
  const CountrySearchEntry({
    required this.iso2,
    required this.name,
    required this.continent,
    required this.focusableOnGlobe,
    required this.visited,
    required this.tripCount,
    required this.latestTripId,
  });

  final String iso2;
  final String name;
  final String? continent;
  final bool focusableOnGlobe;
  final bool visited;
  final int tripCount;
  final int? latestTripId;
}

class SearchCountryRef {
  const SearchCountryRef({
    required this.iso2,
    required this.name,
    required this.continent,
    required this.focusableOnGlobe,
  });

  final String iso2;
  final String name;
  final String? continent;
  final bool focusableOnGlobe;
}

extension FirstOrNullExtension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
