import 'dart:convert';

import 'package:flutter/material.dart';

import '../../data/db/app_db.dart';
import '../../data/repositories/wishlist_repository.dart';
import '../settings/app_preferences.dart';
import 'cloud_trip_planner_client.dart';
import 'gemini_trip_planner.dart';
import 'wishlist_plan_form_types.dart';
import 'wishlist_plan_limits.dart';
import 'wishlist_plan_parsing.dart';

Future<GeminiTripPlan> generateWishlistPlan({
  required AppPreferences prefs,
  required GeminiTripPlanner planner,
  required CloudTripPlannerClient cloudClient,
  required WishlistTimeInputMode timeInputMode,
  required DateTimeRange? dateRange,
  required int? selectedMonth,
  required GeminiDurationPreference? selectedDurationPreference,
  required String countryName,
  required List<String> preferredCities,
  required bool allowAdditionalCities,
  required GeminiTripPlan? currentPlan,
}) async {
  final generatedPlan = prefs.aiPlannerSource == AiPlannerSource.cloud
      ? await cloudClient.generatePlan(
          baseUrl: prefs.cloudAiBaseUrl,
          countryName: countryName,
          homeBase: prefs.homeBase,
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
          countryName: countryName,
          homeBase: prefs.homeBase,
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
  required String? plannedCities,
  GeminiTripPlan? plan,
}) async {
  final id = item.id;
  if (id == null) {
    return;
  }

  final payload = plan == null
      ? item.aiPlan
      : jsonEncode(
          <String, dynamic>{
            ...planner.toStorageJson(plan),
            'request': buildWishlistRequestPayload(
              timeInputMode: timeInputMode,
              allowAdditionalCities: allowAdditionalCities,
              selectedMonth: selectedMonth,
              selectedDurationPreference: selectedDurationPreference,
              dateRange: dateRange,
            ),
          },
        );

  await repository.updateWishlistItem(
    item.copyWith(
      countryName: countryName.isEmpty ? null : countryName,
      countryCode: selectedCountryCode,
      plannedStartDate: timeInputMode == WishlistTimeInputMode.preciseDates
          ? dateRange?.start.millisecondsSinceEpoch
          : null,
      plannedEndDate: timeInputMode == WishlistTimeInputMode.preciseDates
          ? dateRange?.end.millisecondsSinceEpoch
          : null,
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
  required WishlistItemRecord item,
  required WishlistTimeInputMode timeInputMode,
  required DateTimeRange? dateRange,
  required int? selectedMonth,
  required GeminiDurationPreference? selectedDurationPreference,
  required String countryName,
  required bool noCities,
  required String rawCities,
  required bool allowAdditionalCities,
  required String? selectedCountryCode,
  required GeminiTripPlan? currentPlan,
}) async {
  final preferredCities = parseWishlistPreferredCities(
    noCities: noCities,
    rawCities: rawCities,
  );
  final finalizedPlan = await generateWishlistPlan(
    prefs: prefs,
    planner: planner,
    cloudClient: cloudClient,
    timeInputMode: timeInputMode,
    dateRange: dateRange,
    selectedMonth: selectedMonth,
    selectedDurationPreference: selectedDurationPreference,
    countryName: countryName,
    preferredCities: preferredCities,
    allowAdditionalCities: allowAdditionalCities,
    currentPlan: currentPlan,
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
    plannedCities: noCities ? null : rawCities.trim(),
    plan: finalizedPlan,
  );
  return finalizedPlan;
}

int _inclusiveDays(DateTime start, DateTime end) {
  final normalizedStart = DateTime(start.year, start.month, start.day);
  final normalizedEnd = DateTime(end.year, end.month, end.day);
  return normalizedEnd.difference(normalizedStart).inDays + 1;
}
