import 'dart:convert';

import 'package:flutter/material.dart';

import 'gemini_trip_models.dart';

String buildGeminiBasePrompt({
  required String countryName,
  required int generationAttempt,
  String? wishlistTitle,
  String? tripPurpose,
  String? homeBase,
  DateTimeRange? preciseWindow,
  int? preferredMonth,
  GeminiDurationPreference? durationPreference,
  required List<String> preferredCities,
  required bool allowAdditionalCitiesIfTimeAllows,
}) {
  final today = DateTime.now();
  final currentDateText = _formatDate(today);
  final currentYear = today.year;
  final windowText = preciseWindow == null
      ? 'Not provided'
      : '${_formatDate(preciseWindow.start)} to ${_formatDate(preciseWindow.end)} '
          '(${_inclusiveDays(preciseWindow.start, preciseWindow.end)} days)';
  final monthText =
      preferredMonth == null ? 'Not provided' : _monthName(preferredMonth);
  final durationText = durationPreference == null
      ? 'Not provided'
      : '${durationPreference.label} (${durationPreference.minDays}-${durationPreference.maxDays} days)';
  final citiesText =
      preferredCities.isEmpty ? 'None' : preferredCities.join(', ');
  final baseText =
      (homeBase == null || homeBase.isEmpty) ? 'Unknown' : homeBase;
  final titleText = wishlistTitle == null || wishlistTitle.trim().isEmpty
      ? 'Not provided'
      : wishlistTitle.trim();
  final purposeText = tripPurpose == null || tripPurpose.trim().isEmpty
      ? 'Not provided'
      : tripPurpose.trim();
  final isAiTimingMode = preciseWindow == null &&
      preferredMonth == null &&
      durationPreference == null;
  final timingInstruction = isAiTimingMode
      ? '- This request is in ai_decides mode. Pick the best concrete month or short month range for this exact trip and explain why.\n'
          '- In ai_decides mode, the first time_windows item must be the primary recommendation, not a generic season label.\n'
          '- Avoid generic answers like "year-round" unless the purpose truly works any time.\n'
      : '';

  return '''
You are a concise travel planner. Return strict JSON only.

INPUT
- trip_title: $titleText
- country: $countryName
- current_date: $currentDateText
- current_year: $currentYear
- trip_purpose: $purposeText
- generation_attempt: $generationAttempt
- traveler_home_base: $baseText
- precise_date_window: $windowText
- preferred_month: $monthText
- duration_preference: $durationText
- preferred_cities: $citiesText
- allow_extra_cities_if_time_allows: $allowAdditionalCitiesIfTimeAllows

OUTPUT JSON SCHEMA
{
  "country": "string",
  "summary": "max 2 short sentences",
  "duration": {
    "days": 0,
    "reason": "string",
    "source": "user_selected|ai_recommended"
  },
  "recommended_dates": {
    "start": "YYYY-MM-DD",
    "end": "YYYY-MM-DD",
    "reason": "string"
  },
  "time_windows": [
    {
      "label": "string",
      "months": "string",
      "reason": "string"
    }
  ],
  "city_plan": [
    {
      "city": "string",
      "days": 0,
      "reason": "string",
      "is_extra": false
    }
  ]
}

Rules:
- City-level plan only (no hotels/flights).
- Keep city_plan to 1-6 cities.
- Treat trip_purpose as the primary planning brief, not optional flavor text.
- Start by extracting any hard anchors from trip_purpose: named cities, landmarks, day trips, conferences, festivals, holidays, launch sites, museums, beaches, and date-sensitive events.
- Every hard anchor from trip_purpose must appear either in city_plan or inside the reason for the nearest city that supports it.
- Use trip_purpose to influence the summary, timing windows, and city choices when it is provided.
- If trip_purpose mentions a specific city, event, holiday, festival, conference, or target date, treat that as a priority anchor and reflect it in city_plan and reasons.
- If trip_purpose implies the traveler must be in a certain city on a certain date or for a named event, include that city even when it was not listed in preferred_cities.
- If trip_purpose points to a landmark, venue, nearby excursion, or day-trip destination outside the listed city name, route the relevant city around that anchor.
- If trip_purpose mentions a destination outside the city core, like Niagara Falls from New York or Cape Canaveral from Orlando, keep the nearest practical city in city_plan and mention that excursion clearly in the reason.
- Sum of city_plan days must match duration.days with max +/-1.
- If precise_date_window is provided, duration.days must match that window length.
- If precise_date_window is provided, recommended_dates must match that exact window.
- If duration_preference is provided, duration.days must stay inside the range.
- If no duration_preference is provided, set source="ai_recommended".
- time_windows must be concrete and useful. Use month names or short month ranges, not vague phrases alone.
- The first time_windows item should represent the strongest recommendation for this trip.
- If preferred_month is provided, the first time_windows item must honor that month.
- If trip_purpose includes a named event or fixed date, time_windows must reflect that timing anchor directly.
- If this request is in ai_decides mode, recommended_dates is required and must pick concrete dates in the next 18 months.
- Treat current_date as today. Do not recommend dates before current_date.
- Use current_year for date reasoning. If a preferred month has already passed in current_year, choose the next calendar year.
- If this request is in ai_decides mode, recommended_dates should line up with the strongest time window and trip purpose.
- If trip_purpose includes a named event or date anchor, recommended_dates should center around it when realistic.
- If this request is not in ai_decides mode and no precise_date_window was provided, omit recommended_dates.
- If generation_attempt is greater than 1 and there are multiple valid routes, vary the supporting city order or city mix instead of repeating the exact same answer.
- If preferred_cities is not None and allow_extra_cities_if_time_allows=false, use only preferred cities.
- If preferred_cities is not None and allow_extra_cities_if_time_allows=true, add at most 2 nearby cities and only when days are enough.
- Mark added cities with is_extra=true.
- When trip_purpose includes a named event or holiday, use one city_plan reason to mention that anchor briefly.
- Keep reasons concise (under 16 words each).
$timingInstruction
- Avoid returning the same route structure on every attempt when several equally strong routes exist.
''';
}

String buildGeminiCityDetailsPrompt({
  required String countryName,
  required List<GeminiCityPlan> cityPlan,
  required GeminiRecommendedDates? exactDateWindow,
  String? tripPurpose,
}) {
  final compactCityInput = jsonEncode(
    <Map<String, dynamic>>[
      for (final city in cityPlan)
        <String, dynamic>{
          'city': city.city,
          'days': city.days,
        },
    ],
  );
  final purposeText = tripPurpose == null || tripPurpose.trim().isEmpty
      ? 'Not provided'
      : tripPurpose.trim();
  final exactDateText = exactDateWindow == null
      ? 'Not provided'
      : '${_formatDate(exactDateWindow.start)} to ${_formatDate(exactDateWindow.end)}';

  return '''
Create concise city cards for a travel app. Return JSON only.

INPUT
- country: $countryName
- trip_purpose: $purposeText
- exact_trip_dates: $exactDateText
- city_plan: $compactCityInput

OUTPUT JSON SCHEMA
{
  "city_cards": [
    {
      "city": "string",
      "overview": "1 sentence",
      "image_query": "short search query for open-stock city photo",
      "timeline": [
        {
          "slot": "Day X AM/PM",
          "place": "string",
          "note": "short reason"
        }
      ],
      "things_to_do": ["string"]
    }
  ]
}

Rules:
- Return exactly one city_cards item per input city, same city names.
- Use trip_purpose to bias the timeline and things_to_do toward the traveler intent when it is provided.
- If trip_purpose mentions a specific event, city, holiday, or activity, reflect it in the relevant city card timeline and things_to_do.
- If trip_purpose mentions a nearby landmark, venue, launch site, museum, beach, conference center, or excursion outside the city core, include it in the nearest relevant city card.
- If trip_purpose includes a named conference, festival, holiday, or event, put that anchor directly into the relevant city timeline and things_to_do list.
- If trip_purpose includes a day-trip or nearby landmark, include that excursion explicitly in the timeline.
- Timeline must cover every allocated day from city_plan.
- For each city day, include at least a morning and afternoon step, plus an evening step when it naturally fits.
- If exact_trip_dates is provided, use actual calendar labels like "Aug 5 Morning" instead of generic "Day 1 Morning" when possible.
- Otherwise label slots clearly like "Day 1 Morning", "Day 1 Afternoon", "Day 1 Evening".
- things_to_do must be 5-8 concise items and include any must-do purpose anchors that belong in that city.
- Keep all strings short and practical.
''';
}

String _formatDate(DateTime value) {
  final year = value.year.toString().padLeft(4, '0');
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}

int _inclusiveDays(DateTime start, DateTime end) {
  final normalizedStart = DateTime(start.year, start.month, start.day);
  final normalizedEnd = DateTime(end.year, end.month, end.day);
  return normalizedEnd.difference(normalizedStart).inDays + 1;
}

String _monthName(int month) {
  const names = <String>[
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  return names[month - 1];
}
