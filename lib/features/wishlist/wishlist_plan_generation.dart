import 'dart:convert';

import 'package:flutter/material.dart';

import '../../data/db/app_db.dart';
import '../../data/repositories/wishlist_repository.dart';
import '../settings/app_preferences.dart';
import 'cloud_trip_planner_client.dart';
import 'gemini_trip_planner.dart';
import 'gemini_trip_planner_openverse.dart';
import 'wishlist_plan_form_types.dart';
import 'wishlist_plan_limits.dart';
import 'wishlist_plan_parsing.dart';
import 'wishlist_plan_ui_state.dart';

Future<GeminiTripPlan> generateWishlistPlan({
  required AppPreferences prefs,
  required GeminiTripPlanner planner,
  required CloudTripPlannerClient cloudClient,
  required String? accessToken,
  required int generationAttempt,
  required WishlistTimeInputMode timeInputMode,
  required DateTimeRange? dateRange,
  required int? selectedMonth,
  required GeminiDurationPreference? selectedDurationPreference,
  required String itemTitle,
  required String countryName,
  required String? tripPurpose,
  required List<String> preferredCities,
  required bool allowAdditionalCities,
  required GeminiTripPlan? currentPlan,
}) async {
  final generatedPlan = prefs.aiPlannerSource == AiPlannerSource.cloud
      ? await cloudClient.generatePlan(
          baseUrl: prefs.cloudAiBaseUrl,
          accessToken: accessToken ?? '',
          wishlistTitle: itemTitle,
          tripPurpose: tripPurpose,
          countryName: countryName,
          homeBase: prefs.homeBase,
          generationAttempt: generationAttempt,
          preciseWindow: timeInputMode == WishlistTimeInputMode.preciseDates
              ? dateRange
              : null,
          preferredMonth:
              timeInputMode == WishlistTimeInputMode.monthAndDuration
                  ? selectedMonth
                  : null,
          durationPreference:
              timeInputMode == WishlistTimeInputMode.monthAndDuration
                  ? selectedDurationPreference
                  : null,
          preferredCities: preferredCities,
          allowAdditionalCitiesIfTimeAllows:
              preferredCities.isNotEmpty && allowAdditionalCities,
          maxOutputTokens: wishlistPlannerMaxOutputTokens,
        )
      : await planner.generatePlan(
          apiKey: prefs.geminiApiKey,
          wishlistTitle: itemTitle,
          tripPurpose: tripPurpose,
          countryName: countryName,
          homeBase: prefs.homeBase,
          generationAttempt: generationAttempt,
          preciseWindow: timeInputMode == WishlistTimeInputMode.preciseDates
              ? dateRange
              : null,
          preferredMonth:
              timeInputMode == WishlistTimeInputMode.monthAndDuration
                  ? selectedMonth
                  : null,
          durationPreference:
              timeInputMode == WishlistTimeInputMode.monthAndDuration
                  ? selectedDurationPreference
                  : null,
          preferredCities: preferredCities,
          allowAdditionalCitiesIfTimeAllows:
              preferredCities.isNotEmpty && allowAdditionalCities,
        );

  final mergedPlan = currentPlan == null
      ? generatedPlan
      : planner.mergePlans(
          current: currentPlan,
          generated: generatedPlan,
        );

  return planner.hydrateMissingCityImages(
    plan: mergedPlan,
    fallbackCountry: countryName,
  );
}

String? validateWishlistGenerationInputs({
  required String countryName,
  required WishlistTimeInputMode timeInputMode,
  required DateTimeRange? dateRange,
  required int? selectedMonth,
  required GeminiDurationPreference? selectedDurationPreference,
  required bool noCities,
  required String rawCities,
}) {
  if (countryName.isEmpty) {
    return 'Please choose a country first.';
  }
  if (timeInputMode == WishlistTimeInputMode.preciseDates &&
      dateRange == null) {
    return 'Please select a precise date range first.';
  }
  if (timeInputMode == WishlistTimeInputMode.monthAndDuration) {
    if (selectedMonth == null) {
      return 'Please choose a preferred month.';
    }
    if (selectedDurationPreference == null) {
      return 'Please choose one of the four duration options.';
    }
  }

  if (timeInputMode == WishlistTimeInputMode.preciseDates &&
      dateRange != null) {
    final tripLength = _inclusiveDays(dateRange.start, dateRange.end);
    if (tripLength > wishlistMaxTripDays) {
      return 'Trip window is too long. Keep it within $wishlistMaxTripDays days.';
    }
  }

  final cityInputError = validateWishlistCityInput(
    noCities: noCities,
    rawCities: rawCities,
  );
  if (cityInputError != null) {
    return cityInputError;
  }
  return null;
}

List<String> parseWishlistPreferredCities({
  required bool noCities,
  required String rawCities,
}) {
  if (noCities) {
    return const <String>[];
  }
  final analysis = analyzeWishlistCityInput(rawCities);
  if (analysis.cities.length <= wishlistMaxCitiesPerRequest) {
    return analysis.cities;
  }
  return analysis.cities
      .take(wishlistMaxCitiesPerRequest)
      .toList(growable: false);
}

Future<void> saveWishlistPlanDraft({
  required WishlistRepository repository,
  required GeminiTripPlanner planner,
  required WishlistItemRecord item,
  required String countryName,
  required String? selectedCountryCode,
  required WishlistTimeInputMode timeInputMode,
  required DateTimeRange? dateRange,
  required int? selectedMonth,
  required GeminiDurationPreference? selectedDurationPreference,
  required bool allowAdditionalCities,
  required String? tripPurpose,
  required String? plannedCities,
  String? coverImageQuery,
  GeminiCityImage? coverImage,
  GeminiTripPlan? plan,
}) async {
  final id = item.id;
  if (id == null) {
    return;
  }

  final requestPayload = buildWishlistRequestPayload(
    timeInputMode: timeInputMode,
    allowAdditionalCities: allowAdditionalCities,
    purpose: tripPurpose,
    selectedMonth: selectedMonth,
    selectedDurationPreference: selectedDurationPreference,
    dateRange: dateRange,
  );
  final payload = jsonEncode(
    mergeWishlistPlanUiState(
      payload: _buildStoredWishlistPlanPayload(
        planner: planner,
        rawExistingPlan: item.aiPlan,
        plan: plan,
        requestPayload: requestPayload,
        coverImageQuery: coverImageQuery,
        coverImage: coverImage,
      ),
      existingRawPlan: item.aiPlan,
    ),
  );

  await repository.updateWishlistItem(
    item.copyWith(
      countryName: countryName.isEmpty ? null : countryName,
      countryCode: selectedCountryCode,
      plannedStartDate: _resolvedPlannedStartDate(
        timeInputMode: timeInputMode,
        dateRange: dateRange,
        plan: plan,
      ),
      plannedEndDate: _resolvedPlannedEndDate(
        timeInputMode: timeInputMode,
        dateRange: dateRange,
        plan: plan,
      ),
      plannedCities:
          plannedCities == null || plannedCities.isEmpty ? null : plannedCities,
      aiPlan: payload,
    ),
  );
}

Future<GeminiTripPlan> generateAndSaveWishlistPlan({
  required WishlistRepository repository,
  required AppPreferences prefs,
  required GeminiTripPlanner planner,
  required CloudTripPlannerClient cloudClient,
  required String? accessToken,
  required WishlistItemRecord item,
  required WishlistTimeInputMode timeInputMode,
  required DateTimeRange? dateRange,
  required int? selectedMonth,
  required GeminiDurationPreference? selectedDurationPreference,
  required String countryName,
  required String? tripPurpose,
  required bool noCities,
  required String rawCities,
  required bool allowAdditionalCities,
  required String? selectedCountryCode,
  required GeminiTripPlan? currentPlan,
  required int generationAttempt,
}) async {
  final preferredCities = parseWishlistPreferredCities(
    noCities: noCities,
    rawCities: rawCities,
  );
  final finalizedPlan = await generateWishlistPlan(
    prefs: prefs,
    planner: planner,
    cloudClient: cloudClient,
    accessToken: accessToken,
    generationAttempt: generationAttempt,
    timeInputMode: timeInputMode,
    dateRange: dateRange,
    selectedMonth: selectedMonth,
    selectedDurationPreference: selectedDurationPreference,
    itemTitle: item.title,
    countryName: countryName,
    tripPurpose: tripPurpose,
    preferredCities: preferredCities,
    allowAdditionalCities: allowAdditionalCities,
    currentPlan: currentPlan,
  );
  final coverImageQuery = buildWishlistCoverImageQuery(
    title: item.title,
    countryName: countryName,
    purpose: tripPurpose,
    summary: finalizedPlan.summary,
    cityHints: _wishlistCoverCityHints(finalizedPlan),
    cityImageQueries: _wishlistCoverImageQueries(finalizedPlan),
  );
  final coverImage = await findOpenverseImageForWishlistCover(
    title: item.title,
    countryName: countryName,
    purpose: tripPurpose,
    summary: finalizedPlan.summary,
    cityHints: _wishlistCoverCityHints(finalizedPlan),
    cityImageQueries: _wishlistCoverImageQueries(finalizedPlan),
  );
  await saveWishlistPlanDraft(
    repository: repository,
    planner: planner,
    item: item,
    countryName: countryName,
    selectedCountryCode: selectedCountryCode,
    timeInputMode: timeInputMode,
    dateRange: dateRange,
    selectedMonth: selectedMonth,
    selectedDurationPreference: selectedDurationPreference,
    allowAdditionalCities: allowAdditionalCities,
    tripPurpose: tripPurpose,
    plannedCities: noCities ? null : rawCities.trim(),
    coverImageQuery: coverImageQuery,
    coverImage: coverImage,
    plan: finalizedPlan,
  );
  return finalizedPlan;
}

int _inclusiveDays(DateTime start, DateTime end) {
  final normalizedStart = DateTime(start.year, start.month, start.day);
  final normalizedEnd = DateTime(end.year, end.month, end.day);
  return normalizedEnd.difference(normalizedStart).inDays + 1;
}

Map<String, dynamic> _buildStoredWishlistPlanPayload({
  required GeminiTripPlanner planner,
  required String? rawExistingPlan,
  required GeminiTripPlan? plan,
  required Map<String, dynamic> requestPayload,
  required String? coverImageQuery,
  required GeminiCityImage? coverImage,
}) {
  final payload = _decodeStoredPlanMap(rawExistingPlan) ?? <String, dynamic>{};
  if (plan != null) {
    payload
      ..clear()
      ..addAll(planner.toStorageJson(plan));
  }
  payload['request'] = requestPayload;
  if (coverImageQuery != null && coverImageQuery.trim().isNotEmpty) {
    payload['cover_image_query'] = coverImageQuery.trim();
  }
  if (coverImage != null) {
    payload['cover_image'] = <String, dynamic>{
      'image_url': coverImage.imageUrl,
      'source_page_url': coverImage.sourcePageUrl,
      'title': coverImage.title,
      'creator': coverImage.creator,
      'license': coverImage.license,
      'license_url': coverImage.licenseUrl,
      'source': coverImage.source,
    };
  }
  return payload;
}

List<String> _wishlistCoverCityHints(GeminiTripPlan plan) {
  if (plan.cityPlan.isEmpty) {
    return const <String>[];
  }

  final sorted = <GeminiCityPlan>[...plan.cityPlan]
    ..sort((a, b) => b.days.compareTo(a.days));
  return sorted
      .map((city) => city.city.trim())
      .where((city) => city.isNotEmpty)
      .take(3)
      .toList(growable: false);
}

List<String> _wishlistCoverImageQueries(GeminiTripPlan plan) {
  return plan.cityDetails
      .map((detail) => detail.imageQuery.trim())
      .where((query) => query.isNotEmpty)
      .take(3)
      .toList(growable: false);
}

Map<String, dynamic>? _decodeStoredPlanMap(String? rawPlan) {
  final raw = rawPlan?.trim();
  if (raw == null || raw.isEmpty) {
    return null;
  }
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      return null;
    }
    final converted = <String, dynamic>{};
    for (final entry in decoded.entries) {
      converted['${entry.key}'] = entry.value;
    }
    return converted;
  } catch (_) {
    return null;
  }
}

int? _resolvedPlannedStartDate({
  required WishlistTimeInputMode timeInputMode,
  required DateTimeRange? dateRange,
  required GeminiTripPlan? plan,
}) {
  if (timeInputMode == WishlistTimeInputMode.preciseDates) {
    return dateRange?.start.millisecondsSinceEpoch;
  }
  if (timeInputMode == WishlistTimeInputMode.aiRecommended ||
      timeInputMode == WishlistTimeInputMode.monthAndDuration) {
    return plan?.recommendedDates?.start.millisecondsSinceEpoch;
  }
  return null;
}

int? _resolvedPlannedEndDate({
  required WishlistTimeInputMode timeInputMode,
  required DateTimeRange? dateRange,
  required GeminiTripPlan? plan,
}) {
  if (timeInputMode == WishlistTimeInputMode.preciseDates) {
    return dateRange?.end.millisecondsSinceEpoch;
  }
  if (timeInputMode == WishlistTimeInputMode.aiRecommended ||
      timeInputMode == WishlistTimeInputMode.monthAndDuration) {
    return plan?.recommendedDates?.end.millisecondsSinceEpoch;
  }
  return null;
}
