import 'dart:convert';

import 'gemini_trip_models.dart';
import 'gemini_trip_planner_parser_readers.dart';

GeminiTripPlan? parseStoredGeminiPlan(
  String raw, {
  String fallbackCountry = '',
}) {
  final normalizedRaw = raw.trim();
  if (normalizedRaw.isEmpty) {
    return null;
  }

  final decoded = tryDecodeGeminiJson(normalizedRaw);
  if (decoded is Map<String, dynamic>) {
    if (!_containsStoredPlanData(decoded)) {
      return null;
    }
    return geminiTripPlanFromDecodedMap(
      decoded: decoded,
      fallbackCountry: fallbackCountry,
      rawText: raw,
    );
  }

  final parsedFromText = parseBaseGeminiPlanText(
    text: raw,
    fallbackCountry: fallbackCountry,
  );
  if (parsedFromText.summary.trim().isEmpty &&
      parsedFromText.timeWindows.isEmpty &&
      parsedFromText.cityPlan.isEmpty) {
    return null;
  }
  return parsedFromText;
}

bool _containsStoredPlanData(Map<String, dynamic> decoded) {
  if (readGeminiString(decoded['summary']) != null) {
    return true;
  }
  if (isValidGeminiStayDuration(
      _readCandidateStayDuration(decoded['duration']))) {
    return true;
  }
  final timeWindows = decoded['time_windows'];
  if (timeWindows is List && timeWindows.isNotEmpty) {
    return true;
  }
  final cityPlan = decoded['city_plan'];
  if (cityPlan is List && cityPlan.isNotEmpty) {
    return true;
  }
  final cityCards = decoded['city_cards'];
  if (cityCards is List && cityCards.isNotEmpty) {
    return true;
  }
  return false;
}

GeminiStayDuration? _readCandidateStayDuration(dynamic raw) {
  if (raw is! Map) {
    return null;
  }
  final days = raw['days'];
  final parsedDays = days is int
      ? days
      : days is num
          ? days.round()
          : days is String
              ? int.tryParse(days.trim())
              : null;
  if (parsedDays == null || parsedDays <= 0) {
    return null;
  }
  return GeminiStayDuration(
    days: parsedDays,
    reason: readGeminiString(raw['reason']) ?? '',
    source: readGeminiString(raw['source']) ?? 'ai_recommended',
  );
}

GeminiTripPlan parseBaseGeminiPlanText({
  required String text,
  required String fallbackCountry,
}) {
  final trimmed = text.trim();
  final normalized = _stripGeminiMarkdownFence(trimmed);
  final decoded = extractEmbeddedGeminiMap(normalized);
  if (decoded == null) {
    return GeminiTripPlan(
      country: fallbackCountry,
      summary: normalized,
      stayDuration: null,
      timeWindows: const <GeminiTimeWindow>[],
      cityPlan: const <GeminiCityPlan>[],
      cityDetails: const <GeminiCityDetail>[],
      rawText: text,
    );
  }

  return geminiTripPlanFromDecodedMap(
    decoded: decoded,
    fallbackCountry: fallbackCountry,
    rawText: text,
  );
}

List<GeminiCityDetail> parseGeminiCityDetailsText({
  required String text,
  required List<GeminiCityPlan> cityPlan,
}) {
  final normalized = _stripGeminiMarkdownFence(text.trim());
  final decoded = extractEmbeddedGeminiMap(normalized);
  if (decoded == null) {
    return alignGeminiCityDetails(
      cityPlan: cityPlan,
      details: const <GeminiCityDetail>[],
    );
  }
  final details = readGeminiCityDetails(decoded['city_cards']);
  return alignGeminiCityDetails(cityPlan: cityPlan, details: details);
}

bool looksLikeTruncatedGeminiJson(String value) {
  final normalized = _stripGeminiMarkdownFence(value.trim());
  final firstBrace = normalized.indexOf('{');
  if (firstBrace == -1) {
    return false;
  }

  var balance = 0;
  var started = false;
  for (var i = firstBrace; i < normalized.length; i += 1) {
    final char = normalized[i];
    if (char == '{') {
      balance += 1;
      started = true;
    } else if (char == '}') {
      balance -= 1;
    }
  }
  if (started && balance > 0) {
    return true;
  }
  if (_hasUnterminatedGeminiQuotedString(normalized, firstBrace)) {
    return true;
  }
  final trimmed = normalized.trimRight();
  return trimmed.endsWith(':') || trimmed.endsWith(',');
}

List<GeminiCityDetail> alignGeminiCityDetails({
  required List<GeminiCityPlan> cityPlan,
  required List<GeminiCityDetail> details,
}) {
  if (cityPlan.isEmpty) {
    return const <GeminiCityDetail>[];
  }

  final detailByCity = <String, GeminiCityDetail>{
    for (final detail in details) geminiCityKey(detail.city): detail,
  };
  final resolved = <GeminiCityDetail>[];
  for (final city in cityPlan) {
    final key = geminiCityKey(city.city);
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

String geminiCityKey(String value) => value.trim().toLowerCase();

String? readGeminiNonEmpty(String? value) {
  final normalized = value?.trim();
  if (normalized == null || normalized.isEmpty) {
    return null;
  }
  return normalized;
}

bool isValidGeminiStayDuration(GeminiStayDuration? value) {
  return value != null && value.days > 0;
}

String? readGeminiString(dynamic value) {
  if (value is! String) {
    return null;
  }
  final normalized = value.trim();
  if (normalized.isEmpty) {
    return null;
  }
  return normalized;
}

dynamic tryDecodeGeminiJson(String raw) {
  try {
    return jsonDecode(raw);
  } catch (_) {
    return null;
  }
}

String _stripGeminiMarkdownFence(String value) {
  if (!value.startsWith('```')) {
    return value;
  }
  final lines = value.split('\n');
  if (lines.length < 3) {
    return value;
  }
  final withoutStart = lines.skip(1).toList(growable: false);
  if (withoutStart.isNotEmpty && withoutStart.last.trim() == '```') {
    return withoutStart.take(withoutStart.length - 1).join('\n').trim();
  }
  return value;
}

bool _hasUnterminatedGeminiQuotedString(String value, int startIndex) {
  var inString = false;
  var escaped = false;
  for (var i = startIndex; i < value.length; i += 1) {
    final char = value[i];
    if (!inString) {
      if (char == '"') {
        inString = true;
        escaped = false;
      }
      continue;
    }
    if (escaped) {
      escaped = false;
      continue;
    }
    if (char == r'\') {
      escaped = true;
      continue;
    }
    if (char == '"') {
      inString = false;
    }
  }
  return inString;
}
