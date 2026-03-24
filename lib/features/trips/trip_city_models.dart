import 'dart:convert';

import '../../data/db/app_db.dart';
import '../wishlist/gemini_trip_planner.dart';

const _tripCitySentinel = Object();

class TripCityItineraryStop {
  const TripCityItineraryStop({
    required this.slot,
    required this.place,
    required this.note,
  });

  final String slot;
  final String place;
  final String note;

  factory TripCityItineraryStop.fromGemini(GeminiTimelineStop stop) {
    return TripCityItineraryStop(
      slot: stop.slot.trim(),
      place: stop.place.trim(),
      note: stop.note.trim(),
    );
  }

  factory TripCityItineraryStop.fromJson(Map<String, dynamic> json) {
    return TripCityItineraryStop(
      slot: (json['slot'] as String? ?? '').trim(),
      place: (json['place'] as String? ?? '').trim(),
      note: (json['note'] as String? ?? '').trim(),
    );
  }

  TripCityItineraryStop copyWith({
    String? slot,
    String? place,
    String? note,
  }) {
    return TripCityItineraryStop(
      slot: slot ?? this.slot,
      place: place ?? this.place,
      note: note ?? this.note,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'slot': slot.trim(),
      'place': place.trim(),
      'note': note.trim(),
    };
  }
}

class TripCityEntry {
  const TripCityEntry({
    required this.name,
    this.rating,
    this.visitedPlaces = const <String>[],
    this.notes,
    this.imageUri,
    this.itineraryOverview,
    this.itineraryStops = const <TripCityItineraryStop>[],
    this.suggestedPlaces = const <String>[],
    this.completedSuggestedPlaceKeys = const <String>[],
  });

  final String name;
  final int? rating;
  final List<String> visitedPlaces;
  final String? notes;
  final String? imageUri;
  final String? itineraryOverview;
  final List<TripCityItineraryStop> itineraryStops;
  final List<String> suggestedPlaces;
  final List<String> completedSuggestedPlaceKeys;

  factory TripCityEntry.fromJson(Map<String, dynamic> json) {
    final rawVisitedPlaces = json['visitedPlaces'];
    final rawItineraryStops = json['itineraryStops'];
    final rawSuggestedPlaces = json['suggestedPlaces'];
    final rawCompletedSuggestedPlaceKeys = json['completedSuggestedPlaceKeys'];
    return TripCityEntry(
      name: (json['name'] as String? ?? '').trim(),
      rating: _coerceTripCityRating(json['rating']),
      visitedPlaces: rawVisitedPlaces is List
          ? rawVisitedPlaces
              .map((place) => place?.toString().trim() ?? '')
              .where((place) => place.isNotEmpty)
              .toList(growable: false)
          : const <String>[],
      notes: _nullableTrim(json['notes']?.toString()),
      imageUri: _nullableTrim(json['imageUri']?.toString()),
      itineraryOverview: _nullableTrim(json['itineraryOverview']?.toString()),
      itineraryStops: rawItineraryStops is List
          ? rawItineraryStops
              .whereType<Map>()
              .map(
                (stop) => TripCityItineraryStop.fromJson(
                  Map<String, dynamic>.from(stop.cast<String, dynamic>()),
                ),
              )
              .toList(growable: false)
          : const <TripCityItineraryStop>[],
      suggestedPlaces: rawSuggestedPlaces is List
          ? rawSuggestedPlaces
              .map((place) => place?.toString().trim() ?? '')
              .where((place) => place.isNotEmpty)
              .toList(growable: false)
          : const <String>[],
      completedSuggestedPlaceKeys: rawCompletedSuggestedPlaceKeys is List
          ? rawCompletedSuggestedPlaceKeys
              .map((key) => key?.toString().trim() ?? '')
              .where((key) => key.isNotEmpty)
              .toList(growable: false)
          : const <String>[],
    );
  }

  TripCityEntry copyWith({
    String? name,
    Object? rating = _tripCitySentinel,
    Object? visitedPlaces = _tripCitySentinel,
    Object? notes = _tripCitySentinel,
    Object? imageUri = _tripCitySentinel,
    Object? itineraryOverview = _tripCitySentinel,
    Object? itineraryStops = _tripCitySentinel,
    Object? suggestedPlaces = _tripCitySentinel,
    Object? completedSuggestedPlaceKeys = _tripCitySentinel,
  }) {
    return TripCityEntry(
      name: name ?? this.name,
      rating:
          identical(rating, _tripCitySentinel) ? this.rating : rating as int?,
      visitedPlaces: identical(visitedPlaces, _tripCitySentinel)
          ? this.visitedPlaces
          : List<String>.from(visitedPlaces as List<String>),
      notes:
          identical(notes, _tripCitySentinel) ? this.notes : notes as String?,
      imageUri: identical(imageUri, _tripCitySentinel)
          ? this.imageUri
          : imageUri as String?,
      itineraryOverview: identical(itineraryOverview, _tripCitySentinel)
          ? this.itineraryOverview
          : itineraryOverview as String?,
      itineraryStops: identical(itineraryStops, _tripCitySentinel)
          ? this.itineraryStops
          : List<TripCityItineraryStop>.from(
              itineraryStops as List<TripCityItineraryStop>,
            ),
      suggestedPlaces: identical(suggestedPlaces, _tripCitySentinel)
          ? this.suggestedPlaces
          : List<String>.from(suggestedPlaces as List<String>),
      completedSuggestedPlaceKeys:
          identical(completedSuggestedPlaceKeys, _tripCitySentinel)
              ? this.completedSuggestedPlaceKeys
              : List<String>.from(
                  completedSuggestedPlaceKeys as List<String>,
                ),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'name': name.trim(),
      'rating': rating,
      'visitedPlaces': sanitizeTripVisitedPlaces(visitedPlaces),
      'notes': _nullableTrim(notes),
      'imageUri': _nullableTrim(imageUri),
      'itineraryOverview': _nullableTrim(itineraryOverview),
      'itineraryStops': sanitizeTripItineraryStops(itineraryStops)
          .map((stop) => stop.toJson())
          .toList(growable: false),
      'suggestedPlaces': sanitizeTripSuggestedPlaces(suggestedPlaces),
      'completedSuggestedPlaceKeys': sanitizeTripCompletedSuggestedPlaceKeys(
        completedSuggestedPlaceKeys,
        suggestedPlaces: suggestedPlaces,
      ),
    };
  }
}

class TripWishlistInheritance {
  const TripWishlistInheritance({
    required this.item,
    required this.plan,
  });

  final WishlistItemRecord item;
  final GeminiTripPlan? plan;

  List<String> get suggestedCities {
    final fromPlan = plan?.cityPlan
            .map((city) => city.city.trim())
            .where((city) => city.isNotEmpty)
            .toList(growable: false) ??
        const <String>[];
    if (fromPlan.isNotEmpty) {
      return _uniqueTripCityNames(fromPlan);
    }
    return parseTripCityNames(item.plannedCities ?? '');
  }

  GeminiCityPlan? cityPlanFor(String cityName) {
    final key = normalizeTripCityName(cityName);
    if (key.isEmpty) {
      return null;
    }
    for (final city in plan?.cityPlan ?? const <GeminiCityPlan>[]) {
      if (normalizeTripCityName(city.city) == key) {
        return city;
      }
    }
    return null;
  }

  GeminiCityDetail? cityDetailFor(String cityName) {
    final key = normalizeTripCityName(cityName);
    if (key.isEmpty) {
      return null;
    }
    for (final detail in plan?.cityDetails ?? const <GeminiCityDetail>[]) {
      if (normalizeTripCityName(detail.city) == key) {
        return detail;
      }
    }
    return null;
  }
}

String normalizeTripCityName(String value) {
  return value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
}

String normalizeTripSuggestedPlaceKey(String value) {
  return value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
}

List<TripCityEntry> decodeTripCityEntries({
  String? cityDataJson,
  String legacyCities = '',
}) {
  final parsed = _decodeTripCityEntriesFromJson(cityDataJson);
  if (parsed.isNotEmpty) {
    return parsed;
  }
  return parseTripCityNames(legacyCities)
      .map((name) => TripCityEntry(name: name))
      .toList(growable: false);
}

String? encodeTripCityEntries(List<TripCityEntry> cities) {
  final sanitized = sanitizeTripCityEntries(cities);
  if (sanitized.isEmpty) {
    return null;
  }
  return jsonEncode(
    sanitized.map((city) => city.toJson()).toList(growable: false),
  );
}

List<TripCityEntry> sanitizeTripCityEntries(List<TripCityEntry> cities) {
  final seen = <String>{};
  final sanitized = <TripCityEntry>[];
  for (final city in cities) {
    final trimmedName = city.name.trim();
    final key = normalizeTripCityName(trimmedName);
    if (key.isEmpty || !seen.add(key)) {
      continue;
    }
    sanitized.add(
      city.copyWith(
        name: trimmedName,
        visitedPlaces: sanitizeTripVisitedPlaces(city.visitedPlaces),
        notes: _nullableTrim(city.notes),
        imageUri: _nullableTrim(city.imageUri),
        itineraryOverview: _nullableTrim(city.itineraryOverview),
        itineraryStops: sanitizeTripItineraryStops(city.itineraryStops),
        suggestedPlaces: sanitizeTripSuggestedPlaces(city.suggestedPlaces),
        completedSuggestedPlaceKeys: sanitizeTripCompletedSuggestedPlaceKeys(
          city.completedSuggestedPlaceKeys,
          suggestedPlaces: city.suggestedPlaces,
        ),
        rating: _coerceTripCityRating(city.rating),
      ),
    );
  }
  return List<TripCityEntry>.unmodifiable(sanitized);
}

List<String> sanitizeTripVisitedPlaces(List<String> places) {
  final seen = <String>{};
  final sanitized = <String>[];
  for (final place in places) {
    final trimmed = place.trim();
    final key = trimmed.toLowerCase();
    if (trimmed.isEmpty || !seen.add(key)) {
      continue;
    }
    sanitized.add(trimmed);
  }
  return List<String>.unmodifiable(sanitized);
}

List<TripCityItineraryStop> sanitizeTripItineraryStops(
  List<TripCityItineraryStop> stops,
) {
  final sanitized = <TripCityItineraryStop>[];
  for (final stop in stops) {
    final next = stop.copyWith(
      slot: stop.slot.trim(),
      place: stop.place.trim(),
      note: stop.note.trim(),
    );
    if (next.slot.isEmpty && next.place.isEmpty && next.note.isEmpty) {
      continue;
    }
    if (next.place.isEmpty) {
      continue;
    }
    sanitized.add(next);
  }
  return List<TripCityItineraryStop>.unmodifiable(sanitized);
}

List<String> sanitizeTripSuggestedPlaces(List<String> places) {
  final seen = <String>{};
  final sanitized = <String>[];
  for (final place in places) {
    final trimmed = place.trim();
    final key = normalizeTripSuggestedPlaceKey(trimmed);
    if (trimmed.isEmpty || !seen.add(key)) {
      continue;
    }
    sanitized.add(trimmed);
  }
  return List<String>.unmodifiable(sanitized);
}

List<String> sanitizeTripCompletedSuggestedPlaceKeys(
  List<String> keys, {
  List<String> suggestedPlaces = const <String>[],
}) {
  final allowedKeys = suggestedPlaces
      .map(normalizeTripSuggestedPlaceKey)
      .where((key) => key.isNotEmpty)
      .toSet();
  final seen = <String>{};
  final sanitized = <String>[];
  for (final key in keys) {
    final normalized = normalizeTripSuggestedPlaceKey(key);
    if (normalized.isEmpty || !seen.add(normalized)) {
      continue;
    }
    if (allowedKeys.isNotEmpty && !allowedKeys.contains(normalized)) {
      continue;
    }
    sanitized.add(normalized);
  }
  return List<String>.unmodifiable(sanitized);
}

bool tripCityHasSavedItinerary(TripCityEntry city) {
  return (city.itineraryOverview?.trim().isNotEmpty ?? false) ||
      city.itineraryStops.isNotEmpty ||
      city.suggestedPlaces.isNotEmpty;
}

List<String> parseTripCityNames(String raw) {
  if (raw.trim().isEmpty) {
    return const <String>[];
  }
  return _uniqueTripCityNames(
    raw
        .split(RegExp(r'[,;\n]'))
        .map((city) => city.trim())
        .where((city) => city.isNotEmpty)
        .toList(growable: false),
  );
}

String joinTripCityNames(List<TripCityEntry> cities) {
  return sanitizeTripCityEntries(cities).map((city) => city.name).join(', ');
}

TripWishlistInheritance? buildTripWishlistInheritance({
  required WishlistItemRecord? item,
  required GeminiTripPlanner planner,
}) {
  if (item == null) {
    return null;
  }
  return TripWishlistInheritance(
    item: item,
    plan: planner.parseStoredPlan(
      item.aiPlan ?? '',
      fallbackCountry: item.countryName ?? '',
    ),
  );
}

List<TripCityEntry> buildTripCityEntriesFromWishlist(
  TripWishlistInheritance? inheritance,
) {
  if (inheritance == null) {
    return const <TripCityEntry>[];
  }
  return inheritance.suggestedCities
      .map((city) => TripCityEntry(name: city))
      .toList(growable: false);
}

List<String> buildTripCitySuggestions({
  required List<TripCityEntry> cities,
  required TripWishlistInheritance? inheritance,
}) {
  if (inheritance == null) {
    return const <String>[];
  }
  final existingKeys = cities
      .map((city) => normalizeTripCityName(city.name))
      .where((key) => key.isNotEmpty)
      .toSet();
  return inheritance.suggestedCities
      .where((city) => !existingKeys.contains(normalizeTripCityName(city)))
      .toList(growable: false);
}

List<String> _uniqueTripCityNames(List<String> names) {
  final seen = <String>{};
  final unique = <String>[];
  for (final name in names) {
    final trimmed = name.trim();
    final key = normalizeTripCityName(trimmed);
    if (trimmed.isEmpty || !seen.add(key)) {
      continue;
    }
    unique.add(trimmed);
  }
  return List<String>.unmodifiable(unique);
}

List<TripCityEntry> _decodeTripCityEntriesFromJson(String? rawJson) {
  if (rawJson == null || rawJson.trim().isEmpty) {
    return const <TripCityEntry>[];
  }
  try {
    final decoded = jsonDecode(rawJson);
    if (decoded is! List) {
      return const <TripCityEntry>[];
    }
    final entries = decoded
        .whereType<Map>()
        .map(
          (item) => TripCityEntry.fromJson(
            Map<String, dynamic>.from(item.cast<String, dynamic>()),
          ),
        )
        .toList(growable: false);
    return sanitizeTripCityEntries(entries);
  } catch (_) {
    return const <TripCityEntry>[];
  }
}

int? _coerceTripCityRating(Object? value) {
  if (value is int) {
    return (value >= 1 && value <= 5) ? value : null;
  }
  if (value is num) {
    final rounded = value.round();
    return (rounded >= 1 && rounded <= 5) ? rounded : null;
  }
  if (value is String) {
    final parsed = int.tryParse(value.trim());
    if (parsed != null && parsed >= 1 && parsed <= 5) {
      return parsed;
    }
  }
  return null;
}

String? _nullableTrim(String? value) {
  if (value == null) {
    return null;
  }
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}
