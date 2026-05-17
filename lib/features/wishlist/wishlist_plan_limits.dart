const int wishlistMaxCitiesPerRequest = 6;
const int wishlistMaxTripDays = 30;
const int wishlistPlanGenerationCostCredits = 1;
const int wishlistPlannerMaxOutputTokens = 4096;

class WishlistCityInputAnalysis {
  const WishlistCityInputAnalysis({
    required this.rawCount,
    required this.uniqueCount,
    required this.hasDuplicates,
    required this.cities,
  });

  final int rawCount;
  final int uniqueCount;
  final bool hasDuplicates;
  final List<String> cities;
}

WishlistCityInputAnalysis analyzeWishlistCityInput(String rawCities) {
  final parts = rawCities
      .split(',')
      .map((part) => part.trim())
      .where((part) => part.isNotEmpty)
      .toList(growable: false);
  if (parts.isEmpty) {
    return const WishlistCityInputAnalysis(
      rawCount: 0,
      uniqueCount: 0,
      hasDuplicates: false,
      cities: <String>[],
    );
  }

  final seen = <String>{};
  final unique = <String>[];
  var hasDuplicates = false;

  for (final city in parts) {
    final key = city.toLowerCase();
    if (!seen.add(key)) {
      hasDuplicates = true;
      continue;
    }
    unique.add(city);
  }

  return WishlistCityInputAnalysis(
    rawCount: parts.length,
    uniqueCount: unique.length,
    hasDuplicates: hasDuplicates,
    cities: unique,
  );
}

String? validateWishlistCityInput({
  required bool noCities,
  required String rawCities,
}) {
  if (noCities) {
    return null;
  }

  final analysis = analyzeWishlistCityInput(rawCities);
  if (analysis.uniqueCount == 0) {
    return 'Add at least one city, or enable "I don\'t have cities yet".';
  }
  if (analysis.hasDuplicates) {
    return 'Remove duplicate city names before generating.';
  }
  if (analysis.uniqueCount > wishlistMaxCitiesPerRequest) {
    return 'You can add up to $wishlistMaxCitiesPerRequest cities per request.';
  }
  return null;
}
