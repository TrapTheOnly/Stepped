import 'dart:convert';

import 'package:flutter/material.dart';

import 'gemini_trip_models.dart';

String buildGeminiBasePrompt({
  required String countryName,
  String? homeBase,
  DateTimeRange? preciseWindow,
  int? preferredMonth,
  GeminiDurationPreference? durationPreference,
  required List<String> preferredCities,
  required bool allowAdditionalCitiesIfTimeAllows,
}) {
  final windowText = preciseWindow == null
      ? 'Not provided'
      : '${_formatDate(preciseWindow.start)} to ${_formatDate(preciseWindow.end)} '
          '(${_inclusiveDays(preciseWindow.start, preciseWindow.end)} days)';
  final monthText =
      preferredMonth == null ? 'Not provided' : _monthName(preferredMonth);
  final durationText = durationPreference == null
      ? 'Not provided'
      : '${durationPreference.label} (${durationPreference.minDays}-${durationPreference.maxDays} days)';
  final citiesText = preferredCities.isEmpty ? 'None' : preferredCities.join(', ');
  final baseText = (homeBase == null || homeBase.isEmpty) ? 'Unknown' : homeBase;

  return '''
You are a concise travel planner. Return strict JSON only.

INPUT
- country: $countryName
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
- Keep city_plan to 1-4 cities.
- Sum of city_plan days must match duration.days with max +/-1.
- If precise_date_window is provided, duration.days must match that window length.
- If duration_preference is provided, duration.days must stay inside the range.
- If no duration_preference is provided, set source="ai_recommended".
- If preferred_cities is not None and allow_extra_cities_if_time_allows=false, use only preferred cities.
- If preferred_cities is not None and allow_extra_cities_if_time_allows=true, add at most 2 nearby cities and only when days are enough.
- Mark added cities with is_extra=true.
- Keep reasons concise (under 16 words each).
''';
}

String buildGeminiCityDetailsPrompt({
  required String countryName,
  required List<GeminiCityPlan> cityPlan,
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

  return '''
Create concise city cards for a travel app. Return JSON only.

INPUT
- country: $countryName
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
- Timeline must be 3-5 steps in visit order.
- things_to_do must be 4-6 concise items.
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
