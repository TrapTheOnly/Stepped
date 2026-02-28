import 'gemini_trip_models.dart';
import 'gemini_trip_planner_parser.dart';

GeminiTripPlan mergeGeminiTripPlans({
  required GeminiTripPlan current,
  required GeminiTripPlan generated,
}) {
  final mergedCountry = readGeminiNonEmpty(current.country) ?? generated.country;
  final mergedSummary = readGeminiNonEmpty(current.summary) ?? generated.summary;
  final mergedDuration = isValidGeminiStayDuration(current.stayDuration)
      ? current.stayDuration
      : generated.stayDuration;
  final mergedWindows =
      current.timeWindows.isNotEmpty ? current.timeWindows : generated.timeWindows;

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
        city: readGeminiNonEmpty(currentCity.city) ?? generatedCity.city,
        days: currentCity.days > 0 ? currentCity.days : generatedCity.days,
        reason: readGeminiNonEmpty(currentCity.reason) ?? generatedCity.reason,
        isExtra: currentCity.isExtra,
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
  final mergedCityKeys = <String>[];
  for (final city in mergedCityPlan) {
    final key = geminiCityKey(city.city);
    mergedCityKeys.add(key);
    final currentDetail = currentDetailByKey[key];
    final generatedDetail = generatedDetailByKey[key];
    if (currentDetail != null && generatedDetail != null) {
      mergedDetails.add(
        GeminiCityDetail(
          city: readGeminiNonEmpty(currentDetail.city) ?? generatedDetail.city,
          overview: readGeminiNonEmpty(currentDetail.overview) ??
              generatedDetail.overview,
          imageQuery: readGeminiNonEmpty(currentDetail.imageQuery) ??
              generatedDetail.imageQuery,
          timeline: currentDetail.timeline.isNotEmpty
              ? currentDetail.timeline
              : generatedDetail.timeline,
          thingsToDo: currentDetail.thingsToDo.isNotEmpty
              ? currentDetail.thingsToDo
              : generatedDetail.thingsToDo,
          image: currentDetail.image ?? generatedDetail.image,
        ),
      );
      continue;
    }
    if (currentDetail != null) {
      mergedDetails.add(currentDetail);
      continue;
    }
    if (generatedDetail != null) {
      mergedDetails.add(generatedDetail);
    }
  }

  for (final detail in current.cityDetails) {
    final key = geminiCityKey(detail.city);
    if (!mergedCityKeys.contains(key)) {
      mergedDetails.add(detail);
    }
  }
  for (final detail in generated.cityDetails) {
    final key = geminiCityKey(detail.city);
    if (!mergedCityKeys.contains(key)) {
      mergedDetails.add(detail);
    }
  }

  final alignedDetails =
      alignGeminiCityDetails(cityPlan: mergedCityPlan, details: mergedDetails);

  return GeminiTripPlan(
    country: mergedCountry,
    summary: mergedSummary,
    stayDuration: mergedDuration,
    timeWindows: mergedWindows,
    cityPlan: mergedCityPlan,
    cityDetails: alignedDetails,
    rawText:
        generated.rawText.trim().isNotEmpty ? generated.rawText : current.rawText,
  );
}
