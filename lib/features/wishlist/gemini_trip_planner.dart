import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/runtime_config.dart';
import 'gemini_trip_models.dart';
import 'gemini_trip_planner_merge.dart';
import 'gemini_trip_planner_openverse.dart';
import 'gemini_trip_planner_parser.dart';
import 'gemini_trip_planner_prompt_builder.dart';
import 'gemini_trip_planner_request_client.dart';
import 'gemini_trip_planner_storage.dart';
import 'wishlist_plan_limits.dart';
export 'gemini_trip_models.dart';

final geminiTripPlannerProvider = Provider<GeminiTripPlanner>((ref) {
  return const GeminiTripPlanner();
});

class GeminiTripPlanner {
  const GeminiTripPlanner();

  static const int _maxRetryOutputTokens = wishlistPlannerMaxOutputTokens;

  Future<GeminiTripPlan> generatePlan({
    required String apiKey,
    required String countryName,
    String? wishlistTitle,
    String? tripPurpose,
    String? homeBase,
    DateTimeRange? preciseWindow,
    int? preferredMonth,
    GeminiDurationPreference? durationPreference,
    List<String>? preferredCities,
    bool allowAdditionalCitiesIfTimeAllows = false,
  }) async {
    final normalizedKey = apiKey.trim();
    if (normalizedKey.isEmpty) {
      throw const GeminiPlannerException(
        'Missing Gemini API key. Add it in Settings first.',
      );
    }

    final normalizedCountry = countryName.trim();
    if (normalizedCountry.isEmpty) {
      throw const GeminiPlannerException('Country is required.');
    }

    final normalizedCities = (preferredCities ?? const <String>[])
        .map((city) => city.trim())
        .where((city) => city.isNotEmpty)
        .toList(growable: false);
    final uniqueCities = <String>{};
    if (normalizedCities.any((city) => !uniqueCities.add(city.toLowerCase()))) {
      throw const GeminiPlannerException(
        'Remove duplicate city names before generating.',
      );
    }
    if (normalizedCities.length > wishlistMaxCitiesPerRequest) {
      throw const GeminiPlannerException(
          'You can add up to 4 cities per request.');
    }
    final normalizedMonth = (preferredMonth != null &&
            preferredMonth >= DateTime.january &&
            preferredMonth <= DateTime.december)
        ? preferredMonth
        : null;

    final basePrompt = buildGeminiBasePrompt(
      countryName: normalizedCountry,
      wishlistTitle: wishlistTitle,
      tripPurpose: tripPurpose,
      homeBase: homeBase?.trim(),
      preciseWindow: preciseWindow,
      preferredMonth: normalizedMonth,
      durationPreference: durationPreference,
      preferredCities: normalizedCities,
      allowAdditionalCitiesIfTimeAllows:
          allowAdditionalCitiesIfTimeAllows && normalizedCities.isNotEmpty,
    );

    final baseText = await _requestGeminiText(
      apiKey: normalizedKey,
      prompt: basePrompt,
      temperature: 0.2,
      maxOutputTokens: wishlistPlannerMaxOutputTokens,
    );
    final basePlan = parseBaseGeminiPlanText(
      text: baseText,
      fallbackCountry: normalizedCountry,
    );

    if (basePlan.cityPlan.isEmpty) {
      return basePlan;
    }

    final detailsPrompt = buildGeminiCityDetailsPrompt(
      countryName: normalizedCountry,
      cityPlan: basePlan.cityPlan,
      tripPurpose: tripPurpose,
    );
    final detailsText = await _requestGeminiText(
      apiKey: normalizedKey,
      prompt: detailsPrompt,
      temperature: 0.2,
      maxOutputTokens: wishlistPlannerMaxOutputTokens,
    );
    final generatedDetails = parseGeminiCityDetailsText(
      text: detailsText,
      cityPlan: basePlan.cityPlan,
    );
    final detailsWithImages = await attachOpenverseImagesToGeminiCityDetails(
      cityDetails: generatedDetails,
      countryName: normalizedCountry,
    );

    return GeminiTripPlan(
      country: basePlan.country,
      summary: basePlan.summary,
      stayDuration: basePlan.stayDuration,
      timeWindows: basePlan.timeWindows,
      cityPlan: basePlan.cityPlan,
      cityDetails: detailsWithImages,
      rawText: '$baseText\n\n$detailsText',
    );
  }

  Map<String, dynamic> toStorageJson(GeminiTripPlan plan) {
    return geminiPlanToStorageJson(plan);
  }

  GeminiTripPlan? parseStoredPlan(
    String raw, {
    String fallbackCountry = '',
  }) {
    return parseStoredGeminiPlan(raw, fallbackCountry: fallbackCountry);
  }

  Future<GeminiTripPlan> hydrateMissingCityImages({
    required GeminiTripPlan plan,
    String? fallbackCountry,
  }) async {
    final country = readGeminiNonEmpty(plan.country) ??
        readGeminiNonEmpty(fallbackCountry) ??
        'Unknown';
    final details = await attachOpenverseImagesToGeminiCityDetails(
      cityDetails: plan.cityDetails,
      countryName: country,
      onlyMissingImages: true,
    );
    return GeminiTripPlan(
      country: plan.country,
      summary: plan.summary,
      stayDuration: plan.stayDuration,
      timeWindows: plan.timeWindows,
      cityPlan: plan.cityPlan,
      cityDetails:
          alignGeminiCityDetails(cityPlan: plan.cityPlan, details: details),
      rawText: plan.rawText,
    );
  }

  Future<GeminiCityImage?> findOpenImageForCity({
    required String city,
    required String countryName,
    String? imageQuery,
  }) {
    return findOpenverseImageForCity(
      city: city,
      countryName: countryName,
      imageQuery: imageQuery,
    );
  }

  GeminiTripPlan mergePlans({
    required GeminiTripPlan current,
    required GeminiTripPlan generated,
  }) {
    return mergeGeminiTripPlans(current: current, generated: generated);
  }

  Future<String> _requestGeminiText({
    required String apiKey,
    required String prompt,
    required double temperature,
    required int maxOutputTokens,
  }) async {
    final client = GeminiPlannerRequestClient(
      models: defaultGeminiModelCandidates,
      apiVersion: defaultGeminiApiVersion,
      maxRetryOutputTokens: _maxRetryOutputTokens,
    );
    return client.requestText(
      apiKey: apiKey,
      prompt: prompt,
      temperature: temperature,
      maxOutputTokens: maxOutputTokens,
    );
  }
}
