import 'gemini_trip_models.dart';
import 'gemini_trip_planner_parser.dart';

GeminiTripPlan mergeGeminiTripPlans({
  required GeminiTripPlan current,
  required GeminiTripPlan generated,
}) {
  final mergedCountry = readGeminiNonEmpty(generated.country) ?? current.country;
  final mergedSummary = readGeminiNonEmpty(generated.summary) ?? current.summary;
  final mergedDuration = isValidGeminiStayDuration(generated.stayDuration)
      ? generated.stayDuration
      : current.stayDuration;
  final mergedRecommendedDates = generated.recommendedDates;
  final mergedWindows =
      generated.timeWindows.isNotEmpty ? generated.timeWindows : current.timeWindows;

  final generatedCityByKey = <String, GeminiCityPlan>{
    for (final city in generated.cityPlan) geminiCityKey(city.city): city,
  };
  final consumedGeneratedCityKeys = <String>{};
  final mergedCityPlan = <GeminiCityPlan>[];

  for (final currentCity in current.cityPlan) {
    final key = geminiCityKey(currentCity.city);
    final generatedCity = generatedCityByKey[key];
    if (generatedCity == null) {
      mergedCityPlan.add(currentCity);
      continue;
    }
    consumedGeneratedCityKeys.add(key);
      mergedCityPlan.add(
        GeminiCityPlan(
          city: readGeminiNonEmpty(generatedCity.city) ?? currentCity.city,
          days: generatedCity.days > 0 ? generatedCity.days : currentCity.days,
          reason: readGeminiNonEmpty(generatedCity.reason) ?? currentCity.reason,
          isExtra: generatedCity.isExtra,
        ),
      );
    }

  for (final generatedCity in generated.cityPlan) {
    final key = geminiCityKey(generatedCity.city);
    if (!consumedGeneratedCityKeys.contains(key)) {
      mergedCityPlan.add(generatedCity);
    }
  }

  final currentDetailByKey = <String, GeminiCityDetail>{
    for (final detail in current.cityDetails) geminiCityKey(detail.city): detail,
  };
  final generatedDetailByKey = <String, GeminiCityDetail>{
    for (final detail in generated.cityDetails) geminiCityKey(detail.city): detail,
  };

  final mergedDetails = <GeminiCityDetail>[];
  for (final city in mergedCityPlan) {
    final key = geminiCityKey(city.city);
    final currentDetail = currentDetailByKey[key];
    final generatedDetail = generatedDetailByKey[key];
    if (currentDetail != null && generatedDetail != null) {
      mergedDetails.add(
        GeminiCityDetail(
          city: readGeminiNonEmpty(generatedDetail.city) ?? currentDetail.city,
          overview: readGeminiNonEmpty(generatedDetail.overview) ??
              currentDetail.overview,
          imageQuery: readGeminiNonEmpty(generatedDetail.imageQuery) ??
              currentDetail.imageQuery,
          timeline: generatedDetail.timeline.isNotEmpty
              ? generatedDetail.timeline
              : currentDetail.timeline,
          thingsToDo: generatedDetail.thingsToDo.isNotEmpty
              ? generatedDetail.thingsToDo
              : currentDetail.thingsToDo,
          image: generatedDetail.image ?? currentDetail.image,
        ),
      );
      continue;
    }
    if (generatedDetail != null) {
      mergedDetails.add(generatedDetail);
      continue;
    }
    if (currentDetail != null) {
      mergedDetails.add(currentDetail);
    }
  }

  final alignedDetails =
      alignGeminiCityDetails(cityPlan: mergedCityPlan, details: mergedDetails);

  return GeminiTripPlan(
    country: mergedCountry,
    summary: mergedSummary,
    stayDuration: mergedDuration,
    recommendedDates: mergedRecommendedDates,
    timeWindows: mergedWindows,
    cityPlan: mergedCityPlan,
    cityDetails: alignedDetails,
    rawText:
        generated.rawText.trim().isNotEmpty ? generated.rawText : current.rawText,
  );
}
