import 'package:flutter/material.dart';

import '../../data/db/app_db.dart';
import '../map/globe/globe_country_data.dart';
import 'gemini_trip_planner.dart';
import 'wishlist_plan_form_types.dart';
import 'wishlist_plan_parsing.dart';

class WishlistHydrationData {
  const WishlistHydrationData({
    required this.countryText,
    required this.selectedCountryCode,
    required this.citiesText,
    required this.noCities,
    required this.timeInputMode,
    required this.dateRange,
    required this.selectedMonth,
    required this.selectedDurationPreference,
    required this.allowAdditionalCities,
    required this.plan,
  });

  final String countryText;
  final String? selectedCountryCode;
  final String citiesText;
  final bool noCities;
  final WishlistTimeInputMode timeInputMode;
  final DateTimeRange? dateRange;
  final int? selectedMonth;
  final GeminiDurationPreference? selectedDurationPreference;
  final bool allowAdditionalCities;
  final GeminiTripPlan? plan;
}

List<WishlistCountryOption> buildWishlistCountryOptions(
    GlobeCountryDataset? dataset) {
  if (dataset == null) {
    return const <WishlistCountryOption>[];
  }
  final options = dataset.countries
      .map(
        (country) => WishlistCountryOption(
          code: country.iso2.toUpperCase(),
          name: country.name,
        ),
      )
      .toList(growable: false)
    ..sort((left, right) => left.name.compareTo(right.name));
  return options;
}

WishlistHydrationData hydrateWishlistStateFromItem({
  required WishlistItemRecord item,
  required GeminiTripPlanner planner,
}) {
  var timeInputMode = WishlistTimeInputMode.aiRecommended;
  DateTimeRange? dateRange;
  if (item.plannedStartDate != null && item.plannedEndDate != null) {
    dateRange = DateTimeRange(
      start: DateTime.fromMillisecondsSinceEpoch(item.plannedStartDate!),
      end: DateTime.fromMillisecondsSinceEpoch(item.plannedEndDate!),
    );
    timeInputMode = WishlistTimeInputMode.preciseDates;
  }

  int? selectedMonth;
  GeminiDurationPreference? selectedDurationPreference;
  var allowAdditionalCities = true;
  final parsedOptions = item.aiPlan == null
      ? null
      : parseWishlistStoredRequestOptions(item.aiPlan!);
  if (parsedOptions != null) {
    timeInputMode = parsedOptions.timeInputMode;
    if (timeInputMode != WishlistTimeInputMode.preciseDates) {
      dateRange = null;
    }
    selectedMonth = parsedOptions.selectedMonth;
    selectedDurationPreference = parsedOptions.selectedDurationPreference;
    if (parsedOptions.allowAdditionalCities != null) {
      allowAdditionalCities = parsedOptions.allowAdditionalCities!;
    }
  }

  final fallbackCountry = item.countryName ?? '';
  final plan = item.aiPlan == null || item.aiPlan!.trim().isEmpty
      ? null
      : planner.parseStoredPlan(
          item.aiPlan!,
          fallbackCountry: fallbackCountry,
        );

  final seededCities = item.plannedCities?.trim();
  final hasSeededCities = seededCities != null && seededCities.isNotEmpty;
  return WishlistHydrationData(
    countryText: item.countryName ?? '',
    selectedCountryCode: item.countryCode,
    citiesText: seededCities ?? '',
    noCities: !hasSeededCities,
    timeInputMode: timeInputMode,
    dateRange: dateRange,
    selectedMonth: selectedMonth,
    selectedDurationPreference: selectedDurationPreference,
    allowAdditionalCities: allowAdditionalCities,
    plan: plan,
  );
}

String resolveWishlistCountryName({
  required String typedCountry,
  required String? selectedCountryCode,
  required Map<String, WishlistCountryOption> countriesByCode,
}) {
  final typed = typedCountry.trim();
  if (typed.isEmpty) {
    return '';
  }
  if (selectedCountryCode == null) {
    return typed;
  }
  final resolved = countriesByCode[selectedCountryCode.toUpperCase()];
  return resolved?.name ?? typed;
}

String? findSelectedCountryCodeFromQuery({
  required String rawValue,
  required Map<String, WishlistCountryOption> countriesByCode,
}) {
  final query = rawValue.trim().toLowerCase();
  if (query.isEmpty) {
    return null;
  }
  for (final option in countriesByCode.values) {
    if (option.name.toLowerCase() == query ||
        option.code.toLowerCase() == query) {
      return option.code;
    }
  }
  return null;
}
