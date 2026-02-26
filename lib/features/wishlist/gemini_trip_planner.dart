import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class GeminiPlannerException implements Exception {
  const GeminiPlannerException(this.message);

  final String message;

  @override
  String toString() => message;
}

class GeminiTimeWindow {
  const GeminiTimeWindow({
    required this.label,
    required this.months,
    required this.reason,
  });

  final String label;
  final String months;
  final String reason;
}

class GeminiCityPlan {
  const GeminiCityPlan({
    required this.city,
    required this.days,
    required this.reason,
  });

  final String city;
  final int days;
  final String reason;
}

class GeminiTripPlan {
  const GeminiTripPlan({
    required this.country,
    required this.summary,
    required this.timeWindows,
    required this.cityPlan,
    required this.rawText,
  });

  final String country;
  final String summary;
  final List<GeminiTimeWindow> timeWindows;
  final List<GeminiCityPlan> cityPlan;
  final String rawText;
}

final geminiTripPlannerProvider = Provider<GeminiTripPlanner>((ref) {
  return const GeminiTripPlanner();
});

class GeminiTripPlanner {
  const GeminiTripPlanner();

  Future<GeminiTripPlan> generatePlan({
    required String apiKey,
    required String countryName,
    String? homeBase,
    DateTimeRange? plannedWindow,
    List<String>? preferredCities,
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

    final uri = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/'
      'gemini-2.0-flash:generateContent?key=$normalizedKey',
    );

    final prompt = _buildPrompt(
      countryName: normalizedCountry,
      homeBase: homeBase?.trim(),
      plannedWindow: plannedWindow,
      preferredCities: preferredCities ?? const <String>[],
    );

    final payload = <String, dynamic>{
      'contents': <Map<String, dynamic>>[
        <String, dynamic>{
          'parts': <Map<String, dynamic>>[
            <String, dynamic>{
              'text': prompt,
            },
          ],
        },
      ],
      'generationConfig': <String, dynamic>{
        'temperature': 0.25,
        'responseMimeType': 'application/json',
      },
    };

    final client = HttpClient()..connectionTimeout = const Duration(seconds: 15);
    try {
      final request = await client.postUrl(uri);
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode(payload));

      final response = await request.close();
      final rawBody = await response.transform(utf8.decoder).join();
      final body = _tryDecodeJson(rawBody);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        final apiMessage = _extractApiErrorMessage(body) ?? rawBody.trim();
        throw GeminiPlannerException(
          apiMessage.isEmpty
              ? 'Gemini request failed (HTTP ${response.statusCode}).'
              : apiMessage,
        );
      }

      final responseText = _extractText(body);
      if (responseText == null || responseText.trim().isEmpty) {
        throw const GeminiPlannerException(
          'Gemini returned an empty response.',
        );
      }

      return _parsePlanText(
        text: responseText,
        fallbackCountry: normalizedCountry,
      );
    } on SocketException {
      throw const GeminiPlannerException(
        'Network error while contacting Gemini.',
      );
    } on HandshakeException {
      throw const GeminiPlannerException(
        'TLS/SSL handshake failed while contacting Gemini.',
      );
    } on HttpException catch (error) {
      throw GeminiPlannerException(error.message);
    } on FormatException {
      throw const GeminiPlannerException(
        'Failed to parse Gemini response.',
      );
    } finally {
      client.close(force: true);
    }
  }

  String _buildPrompt({
    required String countryName,
    String? homeBase,
    DateTimeRange? plannedWindow,
    required List<String> preferredCities,
  }) {
    final cityList = preferredCities
        .map((city) => city.trim())
        .where((city) => city.isNotEmpty)
        .toList(growable: false);

    final windowText = plannedWindow != null
        ? '${_formatDate(plannedWindow.start)} to ${_formatDate(plannedWindow.end)}'
        : 'No specific date range provided.';
    final citiesText =
        cityList.isEmpty ? 'No preferred cities provided.' : cityList.join(', ');
    final baseText =
        (homeBase == null || homeBase.isEmpty) ? 'Unknown' : homeBase;

    return '''
You are a concise travel planner.

Task:
- Country: $countryName
- Traveler home base: $baseText
- Requested date window: $windowText
- Preferred cities (if any): $citiesText

Return JSON only (no markdown, no prose outside JSON) with this exact shape:
{
  "country": "string",
  "summary": "1-2 sentences",
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
      "reason": "string"
    }
  ]
}

Rules:
- Recommend city-level plan only (no hotels, no flights, no full itinerary details).
- Keep city_plan to 3-6 cities.
- Use practical day counts.
- If preferred cities are provided, prioritize them.
- If requested date window is not ideal, mention that in summary and still suggest best alternatives.
''';
  }

  String _formatDate(DateTime value) {
    final year = value.year.toString().padLeft(4, '0');
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  dynamic _tryDecodeJson(String raw) {
    try {
      return jsonDecode(raw);
    } catch (_) {
      return null;
    }
  }

  String? _extractApiErrorMessage(dynamic body) {
    if (body is! Map<String, dynamic>) {
      return null;
    }
    final error = body['error'];
    if (error is! Map<String, dynamic>) {
      return null;
    }
    final message = error['message'];
    if (message is String && message.trim().isNotEmpty) {
      return message.trim();
    }
    return null;
  }

  String? _extractText(dynamic body) {
    if (body is! Map<String, dynamic>) {
      return null;
    }

    final candidates = body['candidates'];
    if (candidates is! List || candidates.isEmpty) {
      return null;
    }
    final firstCandidate = candidates.first;
    if (firstCandidate is! Map<String, dynamic>) {
      return null;
    }
    final content = firstCandidate['content'];
    if (content is! Map<String, dynamic>) {
      return null;
    }
    final parts = content['parts'];
    if (parts is! List || parts.isEmpty) {
      return null;
    }
    final firstPart = parts.first;
    if (firstPart is! Map<String, dynamic>) {
      return null;
    }
    final text = firstPart['text'];
    if (text is! String) {
      return null;
    }
    return text;
  }

  GeminiTripPlan _parsePlanText({
    required String text,
    required String fallbackCountry,
  }) {
    final trimmed = text.trim();
    final normalized = _stripMarkdownFence(trimmed);
    final firstBrace = normalized.indexOf('{');
    final lastBrace = normalized.lastIndexOf('}');
    if (firstBrace == -1 || lastBrace == -1 || lastBrace <= firstBrace) {
      return GeminiTripPlan(
        country: fallbackCountry,
        summary: normalized,
        timeWindows: const <GeminiTimeWindow>[],
        cityPlan: const <GeminiCityPlan>[],
        rawText: text,
      );
    }

    final jsonText = normalized.substring(firstBrace, lastBrace + 1);
    final decoded = jsonDecode(jsonText);
    if (decoded is! Map<String, dynamic>) {
      return GeminiTripPlan(
        country: fallbackCountry,
        summary: normalized,
        timeWindows: const <GeminiTimeWindow>[],
        cityPlan: const <GeminiCityPlan>[],
        rawText: text,
      );
    }

    final country = _readString(decoded['country']) ?? fallbackCountry;
    final summary = _readString(decoded['summary']) ?? normalized;
    final timeWindows = _readTimeWindows(decoded['time_windows']);
    final cityPlan = _readCityPlan(decoded['city_plan']);

    return GeminiTripPlan(
      country: country,
      summary: summary,
      timeWindows: timeWindows,
      cityPlan: cityPlan,
      rawText: text,
    );
  }

  String _stripMarkdownFence(String value) {
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
      parsed.add(
        GeminiTimeWindow(
          label: label,
          months: months,
          reason: reason,
        ),
      );
    }
    return parsed;
  }

  List<GeminiCityPlan> _readCityPlan(dynamic raw) {
    if (raw is! List) {
      return const <GeminiCityPlan>[];
    }
    final parsed = <GeminiCityPlan>[];
    for (final item in raw) {
      if (item is! Map<String, dynamic>) {
        continue;
      }
      final city = _readString(item['city']);
      final days = _readInt(item['days']);
      final reason = _readString(item['reason']);
      if (city == null || days == null || reason == null) {
        continue;
      }
      parsed.add(
        GeminiCityPlan(
          city: city,
          days: days.clamp(1, 30),
          reason: reason,
        ),
      );
    }
    return parsed;
  }

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
}
