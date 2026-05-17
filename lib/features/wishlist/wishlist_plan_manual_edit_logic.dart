import 'dart:convert';

import '../../data/db/app_db.dart';
import 'gemini_trip_planner.dart';
import 'wishlist_plan_manual_edit_models.dart';

WishlistManualHydratedState hydrateWishlistManualState({
  required WishlistItemRecord item,
  required GeminiTripPlanner planner,
  required int Function() allocateId,
}) {
  final parsedPlan = planner.parseStoredPlan(
    item.aiPlan ?? '',
    fallbackCountry: item.countryName ?? '',
  );

  final seedPlan = parsedPlan ??
      GeminiTripPlan(
        country: item.countryName ?? '',
        summary: '',
        stayDuration: null,
        recommendedDates: null,
        timeWindows: const <GeminiTimeWindow>[],
        cityPlan: const <GeminiCityPlan>[],
        cityDetails: const <GeminiCityDetail>[],
        rawText: '',
      );

  final timeWindows = seedPlan.timeWindows
      .map(
        (window) => EditableTimeWindow(
          id: allocateId(),
          label: window.label,
          months: window.months,
          reason: window.reason,
        ),
      )
      .toList(growable: true);

  final detailByCity = <String, GeminiCityDetail>{
    for (final detail in seedPlan.cityDetails) manualCityKey(detail.city): detail,
  };

  final cities = seedPlan.cityPlan
      .map(
        (city) {
          final detail = detailByCity[manualCityKey(city.city)];
          return EditableCity(
            id: allocateId(),
            originalCityKey: manualCityKey(city.city),
            originalImageQuery: detail?.imageQuery ?? '${city.city} skyline',
            city: city.city,
            days: city.days,
            reason: city.reason,
            isExtra: city.isExtra,
            overview: detail?.overview ?? '',
            imageQuery: detail?.imageQuery ?? '${city.city} skyline',
            image: detail?.image,
            timeline: detail?.timeline
                    .map(
                      (step) => EditableTimeline(
                        id: allocateId(),
                        slot: step.slot,
                        place: step.place,
                        note: step.note,
                      ),
                    )
                    .toList(growable: true) ??
                <EditableTimeline>[],
            thingsToDo: detail?.thingsToDo
                    .map((thing) => EditableThing(id: allocateId(), value: thing))
                    .toList(growable: true) ??
                <EditableThing>[],
          );
        },
      )
      .toList(growable: true);

  return WishlistManualHydratedState(
    country: seedPlan.country,
    summary: seedPlan.summary,
    durationDays: seedPlan.stayDuration?.days.toString() ?? '',
    durationReason: seedPlan.stayDuration?.reason ?? '',
    durationSource: seedPlan.stayDuration?.source == 'user_selected'
        ? 'user_selected'
        : 'ai_recommended',
    coverImage: _readWishlistCoverImage(item.aiPlan),
    timeWindows: timeWindows,
    cities: cities,
    requestPayload: readWishlistManualRequestPayload(item.aiPlan),
  );
}

Map<String, dynamic>? readWishlistManualRequestPayload(String? rawPlan) {
  final raw = rawPlan?.trim();
  if (raw == null || raw.isEmpty) {
    return null;
  }
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      return null;
    }
    final request = decoded['request'];
    if (request is! Map<String, dynamic>) {
      return null;
    }
    return Map<String, dynamic>.from(request);
  } catch (_) {
    return null;
  }
}

String? validateWishlistManualDraft({
  required String country,
  required String summary,
  required String durationDaysRaw,
  required List<EditableCity> cities,
}) {
  if (country.trim().isEmpty) {
    return 'Country is required.';
  }
  if (summary.trim().isEmpty) {
    return 'Summary is required.';
  }

  final durationRaw = durationDaysRaw.trim();
  if (durationRaw.isNotEmpty) {
    final days = int.tryParse(durationRaw);
    if (days == null || days <= 0) {
      return 'Duration days must be a positive number.';
    }
  }

  for (final city in cities) {
    if (city.city.trim().isEmpty) {
      return 'Each city must have a name.';
    }
    if (city.days <= 0) {
      return 'City days must be positive for ${city.city.trim()}.';
    }
    if (city.reason.trim().isEmpty) {
      return 'Each city must have a reason (${city.city.trim()}).';
    }
    for (final step in city.timeline) {
      if (step.slot.trim().isEmpty ||
          step.place.trim().isEmpty ||
          step.note.trim().isEmpty) {
        return 'Timeline entries must include day/slot, place, and note.';
      }
    }
    for (final thing in city.thingsToDo) {
      if (thing.value.trim().isEmpty) {
        return 'Things-to-do entries cannot be empty.';
      }
    }
  }

  return null;
}

GeminiTripPlan? buildWishlistManualDraftPlan({
  required String country,
  required String summary,
  required String durationDaysRaw,
  required String durationReason,
  required String durationSource,
  required List<EditableTimeWindow> timeWindows,
  required List<EditableCity> cities,
}) {
  final trimmedCountry = country.trim();
  final trimmedSummary = summary.trim();
  if (trimmedCountry.isEmpty || trimmedSummary.isEmpty) {
    return null;
  }

  final durationDays = int.tryParse(durationDaysRaw.trim());
  final trimmedDurationReason = durationReason.trim();
  final duration = durationDays == null
      ? null
      : GeminiStayDuration(
          days: durationDays.clamp(1, 45),
          reason: trimmedDurationReason.isEmpty
              ? 'Manual duration updated by user.'
              : trimmedDurationReason,
          source:
              durationSource == 'user_selected' ? 'user_selected' : 'ai_recommended',
        );

  final windows = timeWindows
      .map(
        (window) => GeminiTimeWindow(
          label: window.label.trim(),
          months: window.months.trim(),
          reason: window.reason.trim(),
        ),
      )
      .where(
        (window) =>
            window.label.isNotEmpty &&
            window.months.isNotEmpty &&
            window.reason.isNotEmpty,
      )
      .toList(growable: false);

  final cityPlan = <GeminiCityPlan>[];
  final cityDetails = <GeminiCityDetail>[];
  for (final city in cities) {
    final cityName = city.city.trim();
    if (cityName.isEmpty) {
      continue;
    }

    final keepExistingImage = city.image != null &&
        (city.image!.source == 'manual' ||
            (city.originalCityKey != null &&
                city.originalCityKey == manualCityKey(cityName) &&
                city.originalImageQuery == city.imageQuery.trim()));

    cityPlan.add(
      GeminiCityPlan(
        city: cityName,
        days: city.days.clamp(1, 45),
        reason: city.reason.trim(),
        isExtra: city.isExtra,
      ),
    );

    cityDetails.add(
      GeminiCityDetail(
        city: cityName,
        overview: city.overview.trim(),
        imageQuery:
            city.imageQuery.trim().isEmpty ? '$cityName skyline' : city.imageQuery.trim(),
        timeline: city.timeline
            .map(
              (step) => GeminiTimelineStop(
                slot: step.slot.trim(),
                place: step.place.trim(),
                note: step.note.trim(),
              ),
            )
            .where(
              (step) =>
                  step.slot.isNotEmpty &&
                  step.place.isNotEmpty &&
                  step.note.isNotEmpty,
            )
            .toList(growable: false),
        thingsToDo: city.thingsToDo
            .map((item) => item.value.trim())
            .where((item) => item.isNotEmpty)
            .toList(growable: false),
        image: keepExistingImage ? city.image : null,
      ),
    );
  }

  return GeminiTripPlan(
    country: trimmedCountry,
    summary: trimmedSummary,
    stayDuration: duration,
    recommendedDates: null,
    timeWindows: windows,
    cityPlan: cityPlan,
    cityDetails: cityDetails,
    rawText: '',
  );
}

GeminiCityImage? _readWishlistCoverImage(String? rawPlan) {
  final raw = rawPlan?.trim();
  if (raw == null || raw.isEmpty) {
    return null;
  }

  try {
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      return null;
    }
    final coverImage = decoded['cover_image'];
    if (coverImage is! Map<String, dynamic>) {
      return null;
    }
    final imageUrl = coverImage['image_url'];
    if (imageUrl is! String || imageUrl.trim().isEmpty) {
      return null;
    }
    return GeminiCityImage(
      imageUrl: imageUrl.trim(),
      sourcePageUrl: (coverImage['source_page_url'] as String?) ?? '',
      title: (coverImage['title'] as String?) ?? 'Wishlist cover',
      creator: (coverImage['creator'] as String?) ?? 'Unknown creator',
      license: (coverImage['license'] as String?) ?? 'unknown',
      licenseUrl: (coverImage['license_url'] as String?) ?? '',
      source: (coverImage['source'] as String?) ?? 'openverse',
    );
  } catch (_) {
    return null;
  }
}
