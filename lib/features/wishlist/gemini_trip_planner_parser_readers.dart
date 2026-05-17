import 'dart:convert';

import 'gemini_trip_models.dart';
import 'wishlist_plan_limits.dart';

GeminiTripPlan geminiTripPlanFromDecodedMap({
  required Map<String, dynamic> decoded,
  required String fallbackCountry,
  required String rawText,
}) {
  final country = _readString(decoded['country']) ?? fallbackCountry;
  final summary = _readString(decoded['summary']) ?? '';
  final stayDuration = _readStayDuration(decoded['duration']);
  final recommendedDates = _readRecommendedDates(decoded['recommended_dates']);
  final timeWindows = _readTimeWindows(decoded['time_windows']);
  final cityPlan = _readCityPlan(decoded['city_plan']);
  final cityDetailsFromPayload = readGeminiCityDetails(decoded['city_cards']);
  final cityDetails = _alignCityDetails(cityPlan: cityPlan, details: cityDetailsFromPayload);

  return GeminiTripPlan(
    country: country,
    summary: summary,
    stayDuration: stayDuration,
    recommendedDates: recommendedDates,
    timeWindows: timeWindows,
    cityPlan: cityPlan,
    cityDetails: cityDetails,
    rawText: rawText,
  );
}

Map<String, dynamic>? extractEmbeddedGeminiMap(String value) {
  final firstBrace = value.indexOf('{');
  final lastBrace = value.lastIndexOf('}');
  if (firstBrace == -1 || lastBrace == -1 || lastBrace <= firstBrace) {
    return null;
  }
  final jsonText = value.substring(firstBrace, lastBrace + 1);
  final decoded = _tryDecodeGeminiJson(jsonText);
  if (decoded is! Map<String, dynamic>) {
    return null;
  }
  return decoded;
}

List<GeminiCityDetail> readGeminiCityDetails(dynamic raw) {
  if (raw is! List) {
    return const <GeminiCityDetail>[];
  }
  final parsed = <GeminiCityDetail>[];
  for (final item in raw) {
    if (item is! Map<String, dynamic>) {
      continue;
    }
    final city = _readString(item['city']);
    if (city == null) {
      continue;
    }
    parsed.add(
      GeminiCityDetail(
        city: city,
        overview: _readString(item['overview']) ?? '',
        imageQuery: _readString(item['image_query']) ?? '$city skyline',
        timeline: _readTimeline(item['timeline']),
        thingsToDo: _readStringList(item['things_to_do']),
        image: _readCityImage(item['image']),
      ),
    );
  }
  return parsed;
}

dynamic _tryDecodeGeminiJson(String raw) {
  try {
    return jsonDecode(raw);
  } catch (_) {
    return null;
  }
}

GeminiStayDuration? _readStayDuration(dynamic raw) {
  if (raw is! Map<String, dynamic>) {
    return null;
  }
  final days = _readInt(raw['days']);
  final reason = _readString(raw['reason']);
  if (days == null || reason == null) {
    return null;
  }
  final source = _readString(raw['source'])?.toLowerCase() ?? 'ai_recommended';
  final normalizedSource = source == 'user_selected' ? 'user_selected' : 'ai_recommended';
  return GeminiStayDuration(
    days: days.clamp(1, 45),
    reason: reason,
    source: normalizedSource,
  );
}

GeminiRecommendedDates? _readRecommendedDates(dynamic raw) {
  if (raw is! Map<String, dynamic>) {
    return null;
  }
  final start = _readDate(raw['start']);
  final end = _readDate(raw['end']);
  final reason = _readString(raw['reason']);
  if (start == null || end == null || reason == null) {
    return null;
  }
  if (end.isBefore(start)) {
    return null;
  }
  return GeminiRecommendedDates(
    start: start,
    end: end,
    reason: reason,
  );
}

List<GeminiTimeWindow> _readTimeWindows(dynamic raw) {
  if (raw is! List) {
    return const <GeminiTimeWindow>[];
  }
  final parsed = <GeminiTimeWindow>[];
  for (final item in raw) {
    if (item is! Map<String, dynamic>) {
      continue;
    }
    final label = _readString(item['label']);
    final months = _readString(item['months']);
    final reason = _readString(item['reason']);
    if (label == null || months == null || reason == null) {
      continue;
    }
    parsed.add(GeminiTimeWindow(label: label, months: months, reason: reason));
  }
  return parsed;
}

List<GeminiCityPlan> _readCityPlan(dynamic raw) {
  if (raw is! List) {
    return const <GeminiCityPlan>[];
  }
  final parsed = <GeminiCityPlan>[];
  final seen = <String>{};
  for (final item in raw) {
    if (item is! Map<String, dynamic>) {
      continue;
    }
    final city = _readString(item['city']);
    final days = _readInt(item['days']);
    final reason = _readString(item['reason']);
    final isExtra = _readBool(item['is_extra']) ?? false;
    if (city == null || days == null || reason == null) {
      continue;
    }
    final key = city.toLowerCase();
    if (!seen.add(key)) {
      continue;
    }
    parsed.add(
      GeminiCityPlan(
        city: city,
        days: days.clamp(1, wishlistMaxTripDays),
        reason: reason,
        isExtra: isExtra,
      ),
    );
    if (parsed.length >= wishlistMaxCitiesPerRequest) {
      break;
    }
  }
  return parsed;
}

List<GeminiTimelineStop> _readTimeline(dynamic raw) {
  if (raw is! List) {
    return const <GeminiTimelineStop>[];
  }
  final parsed = <GeminiTimelineStop>[];
  for (final item in raw) {
    if (item is! Map<String, dynamic>) {
      continue;
    }
    final slot = _readString(item['slot']);
    final place = _readString(item['place']);
    final note = _readString(item['note']);
    if (slot == null || place == null || note == null) {
      continue;
    }
    parsed.add(GeminiTimelineStop(slot: slot, place: place, note: note));
  }
  return parsed;
}

GeminiCityImage? _readCityImage(dynamic raw) {
  if (raw is! Map<String, dynamic>) {
    return null;
  }
  final imageUrl = _readString(raw['image_url']);
  if (imageUrl == null) {
    return null;
  }
  return GeminiCityImage(
    imageUrl: imageUrl,
    sourcePageUrl: _readString(raw['source_page_url']) ?? '',
    title: _readString(raw['title']) ?? 'City image',
    creator: _readString(raw['creator']) ?? 'Unknown creator',
    license: _readString(raw['license']) ?? 'unknown',
    licenseUrl: _readString(raw['license_url']) ?? '',
    source: _readString(raw['source']) ?? 'openverse',
  );
}

List<String> _readStringList(dynamic raw) {
  if (raw is! List) {
    return const <String>[];
  }
  final parsed = <String>[];
  for (final item in raw) {
    final value = _readString(item);
    if (value != null) {
      parsed.add(value);
    }
  }
  return parsed;
}

List<GeminiCityDetail> _alignCityDetails({
  required List<GeminiCityPlan> cityPlan,
  required List<GeminiCityDetail> details,
}) {
  if (cityPlan.isEmpty) {
    return const <GeminiCityDetail>[];
  }

  final detailByCity = <String, GeminiCityDetail>{
    for (final detail in details) _cityKey(detail.city): detail,
  };
  final resolved = <GeminiCityDetail>[];
  for (final city in cityPlan) {
    final key = _cityKey(city.city);
    final detail = detailByCity.remove(key);
    if (detail != null) {
      resolved.add(detail);
    } else {
      resolved.add(
        GeminiCityDetail(
          city: city.city,
          overview: city.reason,
          imageQuery: '${city.city} skyline',
          timeline: const <GeminiTimelineStop>[],
          thingsToDo: const <String>[],
        ),
      );
    }
  }
  resolved.addAll(detailByCity.values);
  return resolved;
}

String _cityKey(String value) => value.trim().toLowerCase();

String? _readString(dynamic value) {
  if (value is! String) {
    return null;
  }
  final normalized = value.trim();
  if (normalized.isEmpty) {
    return null;
  }
  return normalized;
}

int? _readInt(dynamic value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.round();
  }
  if (value is String) {
    return int.tryParse(value.trim());
  }
  return null;
}

bool? _readBool(dynamic value) {
  if (value is bool) {
    return value;
  }
  if (value is num) {
    return value != 0;
  }
  if (value is! String) {
    return null;
  }
  final normalized = value.trim().toLowerCase();
  if (normalized == 'true' || normalized == '1' || normalized == 'yes') {
    return true;
  }
  if (normalized == 'false' || normalized == '0' || normalized == 'no') {
    return false;
  }
  return null;
}

DateTime? _readDate(dynamic value) {
  final raw = _readString(value);
  if (raw == null) {
    return null;
  }
  return DateTime.tryParse(raw);
}
