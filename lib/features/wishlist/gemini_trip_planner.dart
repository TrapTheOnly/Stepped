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

class GeminiDurationPreference {
  const GeminiDurationPreference({
    required this.id,
    required this.label,
    required this.minDays,
    required this.maxDays,
    required this.description,
  });

  final String id;
  final String label;
  final int minDays;
  final int maxDays;
  final String description;
}

const List<GeminiDurationPreference> geminiDurationPreferences =
    <GeminiDurationPreference>[
  GeminiDurationPreference(
    id: 'quick_escape',
    label: 'Quick Escape',
    minDays: 3,
    maxDays: 5,
    description: 'Short, high-energy city break.',
  ),
  GeminiDurationPreference(
    id: 'balanced_week',
    label: 'Balanced Week',
    minDays: 6,
    maxDays: 8,
    description: 'Comfortable pace with top highlights.',
  ),
  GeminiDurationPreference(
    id: 'deep_dive',
    label: 'Deep Dive',
    minDays: 9,
    maxDays: 12,
    description: 'More neighborhoods and city depth.',
  ),
  GeminiDurationPreference(
    id: 'grand_journey',
    label: 'Grand Journey',
    minDays: 13,
    maxDays: 18,
    description: 'Slower pace and broader coverage.',
  ),
];

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

class GeminiStayDuration {
  const GeminiStayDuration({
    required this.days,
    required this.reason,
    required this.source,
  });

  final int days;
  final String reason;
  final String source;
}

class GeminiCityPlan {
  const GeminiCityPlan({
    required this.city,
    required this.days,
    required this.reason,
    required this.isExtra,
  });

  final String city;
  final int days;
  final String reason;
  final bool isExtra;
}

class GeminiTimelineStop {
  const GeminiTimelineStop({
    required this.slot,
    required this.place,
    required this.note,
  });

  final String slot;
  final String place;
  final String note;
}

class GeminiCityImage {
  const GeminiCityImage({
    required this.imageUrl,
    required this.sourcePageUrl,
    required this.title,
    required this.creator,
    required this.license,
    required this.licenseUrl,
    required this.source,
  });

  final String imageUrl;
  final String sourcePageUrl;
  final String title;
  final String creator;
  final String license;
  final String licenseUrl;
  final String source;
}

class GeminiCityDetail {
  const GeminiCityDetail({
    required this.city,
    required this.overview,
    required this.imageQuery,
    required this.timeline,
    required this.thingsToDo,
    this.image,
  });

  final String city;
  final String overview;
  final String imageQuery;
  final List<GeminiTimelineStop> timeline;
  final List<String> thingsToDo;
  final GeminiCityImage? image;

  GeminiCityDetail copyWith({
    GeminiCityImage? image,
  }) {
    return GeminiCityDetail(
      city: city,
      overview: overview,
      imageQuery: imageQuery,
      timeline: timeline,
      thingsToDo: thingsToDo,
      image: image ?? this.image,
    );
  }
}

class GeminiTripPlan {
  const GeminiTripPlan({
    required this.country,
    required this.summary,
    required this.stayDuration,
    required this.timeWindows,
    required this.cityPlan,
    required this.cityDetails,
    required this.rawText,
  });

  final String country;
  final String summary;
  final GeminiStayDuration? stayDuration;
  final List<GeminiTimeWindow> timeWindows;
  final List<GeminiCityPlan> cityPlan;
  final List<GeminiCityDetail> cityDetails;
  final String rawText;
}

final geminiTripPlannerProvider = Provider<GeminiTripPlanner>((ref) {
  return const GeminiTripPlanner();
});

class GeminiTripPlanner {
  const GeminiTripPlanner();

  static const List<String> _modelCandidates = <String>[
    'gemini-3-flash',
    'gemini-3.0-flash',
    'gemini-3-flash-preview',
  ];
  static const int _maxRetryOutputTokens = 4096;

  Future<GeminiTripPlan> generatePlan({
    required String apiKey,
    required String countryName,
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
    final normalizedMonth = (preferredMonth != null &&
            preferredMonth >= DateTime.january &&
            preferredMonth <= DateTime.december)
        ? preferredMonth
        : null;

    final basePrompt = _buildBasePrompt(
      countryName: normalizedCountry,
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
      maxOutputTokens: 1400,
    );
    final basePlan = _parseBasePlanText(
      text: baseText,
      fallbackCountry: normalizedCountry,
    );

    if (basePlan.cityPlan.isEmpty) {
      return basePlan;
    }

    final detailsPrompt = _buildCityDetailsPrompt(
      countryName: normalizedCountry,
      cityPlan: basePlan.cityPlan,
    );
    final detailsText = await _requestGeminiText(
      apiKey: normalizedKey,
      prompt: detailsPrompt,
      temperature: 0.2,
      maxOutputTokens: 2200,
    );
    final generatedDetails = _parseCityDetailsText(
      text: detailsText,
      cityPlan: basePlan.cityPlan,
    );
    final detailsWithImages = await _attachOpenImages(
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
    return <String, dynamic>{
      'country': plan.country,
      'summary': plan.summary,
      'duration': plan.stayDuration == null
          ? null
          : <String, dynamic>{
              'days': plan.stayDuration!.days,
              'reason': plan.stayDuration!.reason,
              'source': plan.stayDuration!.source,
            },
      'time_windows': <Map<String, dynamic>>[
        for (final window in plan.timeWindows)
          <String, dynamic>{
            'label': window.label,
            'months': window.months,
            'reason': window.reason,
          },
      ],
      'city_plan': <Map<String, dynamic>>[
        for (final city in plan.cityPlan)
          <String, dynamic>{
            'city': city.city,
            'days': city.days,
            'reason': city.reason,
            'is_extra': city.isExtra,
          },
      ],
      'city_cards': <Map<String, dynamic>>[
        for (final card in plan.cityDetails)
          <String, dynamic>{
            'city': card.city,
            'overview': card.overview,
            'image_query': card.imageQuery,
            'timeline': <Map<String, dynamic>>[
              for (final stop in card.timeline)
                <String, dynamic>{
                  'slot': stop.slot,
                  'place': stop.place,
                  'note': stop.note,
                },
            ],
            'things_to_do': <String>[
              for (final item in card.thingsToDo) item,
            ],
            'image': card.image == null
                ? null
                : <String, dynamic>{
                    'image_url': card.image!.imageUrl,
                    'source_page_url': card.image!.sourcePageUrl,
                    'title': card.image!.title,
                    'creator': card.image!.creator,
                    'license': card.image!.license,
                    'license_url': card.image!.licenseUrl,
                    'source': card.image!.source,
                  },
          },
      ],
    };
  }

  GeminiTripPlan? parseStoredPlan(
    String raw, {
    String fallbackCountry = '',
  }) {
    final normalizedRaw = raw.trim();
    if (normalizedRaw.isEmpty) {
      return null;
    }

    final decoded = _tryDecodeJson(normalizedRaw);
    if (decoded is Map<String, dynamic>) {
      return _planFromMap(
        decoded: decoded,
        fallbackCountry: fallbackCountry,
        rawText: raw,
      );
    }

    final parsedFromText = _parseBasePlanText(
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

  GeminiTripPlan mergePlans({
    required GeminiTripPlan current,
    required GeminiTripPlan generated,
  }) {
    final mergedCountry = _readNonEmpty(current.country) ?? generated.country;
    final mergedSummary = _readNonEmpty(current.summary) ?? generated.summary;
    final mergedDuration = _isValidStayDuration(current.stayDuration)
        ? current.stayDuration
        : generated.stayDuration;
    final mergedWindows = current.timeWindows.isNotEmpty
        ? current.timeWindows
        : generated.timeWindows;

    final generatedCityByKey = <String, GeminiCityPlan>{
      for (final city in generated.cityPlan) _cityKey(city.city): city,
    };
    final consumedGeneratedCityKeys = <String>{};
    final mergedCityPlan = <GeminiCityPlan>[];

    for (final currentCity in current.cityPlan) {
      final key = _cityKey(currentCity.city);
      final generatedCity = generatedCityByKey[key];
      if (generatedCity == null) {
        mergedCityPlan.add(currentCity);
        continue;
      }
      consumedGeneratedCityKeys.add(key);
      mergedCityPlan.add(
        GeminiCityPlan(
          city: _readNonEmpty(currentCity.city) ?? generatedCity.city,
          days: currentCity.days > 0 ? currentCity.days : generatedCity.days,
          reason: _readNonEmpty(currentCity.reason) ?? generatedCity.reason,
          isExtra: currentCity.isExtra,
        ),
      );
    }

    for (final generatedCity in generated.cityPlan) {
      final key = _cityKey(generatedCity.city);
      if (consumedGeneratedCityKeys.contains(key)) {
        continue;
      }
      mergedCityPlan.add(generatedCity);
    }

    final currentDetailByKey = <String, GeminiCityDetail>{
      for (final detail in current.cityDetails) _cityKey(detail.city): detail,
    };
    final generatedDetailByKey = <String, GeminiCityDetail>{
      for (final detail in generated.cityDetails) _cityKey(detail.city): detail,
    };

    final mergedDetails = <GeminiCityDetail>[];
    final mergedCityKeys = <String>[];
    for (final city in mergedCityPlan) {
      final key = _cityKey(city.city);
      mergedCityKeys.add(key);
      final currentDetail = currentDetailByKey[key];
      final generatedDetail = generatedDetailByKey[key];
      if (currentDetail != null && generatedDetail != null) {
        mergedDetails.add(
          GeminiCityDetail(
            city: _readNonEmpty(currentDetail.city) ?? generatedDetail.city,
            overview: _readNonEmpty(currentDetail.overview) ??
                generatedDetail.overview,
            imageQuery: _readNonEmpty(currentDetail.imageQuery) ??
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
      final key = _cityKey(detail.city);
      if (!mergedCityKeys.contains(key)) {
        mergedDetails.add(detail);
      }
    }
    for (final detail in generated.cityDetails) {
      final key = _cityKey(detail.city);
      if (!mergedCityKeys.contains(key)) {
        mergedDetails.add(detail);
      }
    }

    final alignedDetails =
        _alignCityDetails(cityPlan: mergedCityPlan, details: mergedDetails);

    return GeminiTripPlan(
      country: mergedCountry,
      summary: mergedSummary,
      stayDuration: mergedDuration,
      timeWindows: mergedWindows,
      cityPlan: mergedCityPlan,
      cityDetails: alignedDetails,
      rawText: generated.rawText.trim().isNotEmpty
          ? generated.rawText
          : current.rawText,
    );
  }

  Future<GeminiTripPlan> hydrateMissingCityImages({
    required GeminiTripPlan plan,
    String? fallbackCountry,
  }) async {
    final country = _readNonEmpty(plan.country) ??
        _readNonEmpty(fallbackCountry) ??
        'Unknown';
    final details = await _attachOpenImages(
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
      cityDetails: _alignCityDetails(cityPlan: plan.cityPlan, details: details),
      rawText: plan.rawText,
    );
  }

  Future<GeminiCityImage?> findOpenImageForCity({
    required String city,
    required String countryName,
    String? imageQuery,
  }) {
    return _findOpenImageForCity(
      city: city,
      countryName: countryName,
      imageQuery: _readNonEmpty(imageQuery) ?? '$city skyline',
    );
  }

  String _buildBasePrompt({
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
    final citiesText =
        preferredCities.isEmpty ? 'None' : preferredCities.join(', ');
    final baseText =
        (homeBase == null || homeBase.isEmpty) ? 'Unknown' : homeBase;

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
- Keep city_plan to 2-6 cities.
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

  String _buildCityDetailsPrompt({
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

  Future<String> _requestGeminiText({
    required String apiKey,
    required String prompt,
    required double temperature,
    required int maxOutputTokens,
  }) async {
    GeminiPlannerException? lastMissingModelError;
    for (var index = 0; index < _modelCandidates.length; index += 1) {
      final model = _modelCandidates[index];
      try {
        return await _requestGeminiTextForModel(
          model: model,
          apiKey: apiKey,
          prompt: prompt,
          temperature: temperature,
          maxOutputTokens: maxOutputTokens,
        );
      } on GeminiPlannerException catch (error) {
        final isLast = index == _modelCandidates.length - 1;
        if (!isLast && _looksLikeMissingModel(error.message)) {
          lastMissingModelError = error;
          continue;
        }
        rethrow;
      }
    }
    throw lastMissingModelError ??
        const GeminiPlannerException('Gemini request failed.');
  }

  Future<String> _requestGeminiTextForModel({
    required String model,
    required String apiKey,
    required String prompt,
    required double temperature,
    required int maxOutputTokens,
  }) async {
    final uri = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/'
      '$model:generateContent?key=$apiKey',
    );

    final tokenBudgets = <int>[
      maxOutputTokens,
      if (maxOutputTokens < _maxRetryOutputTokens)
        (maxOutputTokens * 2).clamp(maxOutputTokens + 1, _maxRetryOutputTokens),
      if (_maxRetryOutputTokens > (maxOutputTokens * 2)) _maxRetryOutputTokens,
    ];

    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 15);
    try {
      for (var attempt = 0; attempt < tokenBudgets.length; attempt += 1) {
        final tokenBudget = tokenBudgets[attempt];
        final attemptTemperature = attempt == tokenBudgets.length - 1
            ? (temperature * 0.6).clamp(0.0, temperature)
            : temperature;
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
            'temperature': attemptTemperature,
            'responseMimeType': 'application/json',
            'maxOutputTokens': tokenBudget,
          },
        };

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

        final responsePayload = _extractTextPayload(body);
        final responseText = responsePayload.text?.trim();
        if (responseText == null || responseText.isEmpty) {
          throw const GeminiPlannerException(
            'Gemini returned an empty response.',
          );
        }

        final hitTokenLimit =
            responsePayload.finishReason.toUpperCase() == 'MAX_TOKENS';
        final looksTruncated = _looksLikeTruncatedJson(responseText);
        final shouldRetry = (hitTokenLimit || looksTruncated) &&
            attempt < tokenBudgets.length - 1;
        if (shouldRetry) {
          continue;
        }
        if (hitTokenLimit || looksTruncated) {
          throw const GeminiPlannerException(
            'Gemini response was truncated before completing valid JSON. Please try again.',
          );
        }
        return responseText;
      }

      throw const GeminiPlannerException(
        'Gemini response could not be completed.',
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

  bool _looksLikeMissingModel(String message) {
    final normalized = message.toLowerCase();
    return normalized.contains('is not found') ||
        normalized.contains('not found for api version') ||
        normalized.contains('unsupported model') ||
        normalized.contains('does not exist');
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

  _GeminiTextPayload _extractTextPayload(dynamic body) {
    if (body is! Map<String, dynamic>) {
      return const _GeminiTextPayload(text: null, finishReason: '');
    }

    final candidates = body['candidates'];
    if (candidates is! List || candidates.isEmpty) {
      return const _GeminiTextPayload(text: null, finishReason: '');
    }
    final firstCandidate = candidates.first;
    if (firstCandidate is! Map<String, dynamic>) {
      return const _GeminiTextPayload(text: null, finishReason: '');
    }
    final finishReason =
        _readString(firstCandidate['finishReason'])?.toUpperCase() ?? '';
    final content = firstCandidate['content'];
    if (content is! Map<String, dynamic>) {
      return _GeminiTextPayload(text: null, finishReason: finishReason);
    }
    final parts = content['parts'];
    if (parts is! List || parts.isEmpty) {
      return _GeminiTextPayload(text: null, finishReason: finishReason);
    }
    final textBuffer = StringBuffer();
    for (final part in parts) {
      if (part is! Map<String, dynamic>) {
        continue;
      }
      final text = part['text'];
      if (text is String && text.isNotEmpty) {
        textBuffer.write(text);
      }
    }
    final aggregated = textBuffer.toString();
    if (aggregated.isEmpty) {
      return _GeminiTextPayload(text: null, finishReason: finishReason);
    }
    return _GeminiTextPayload(text: aggregated, finishReason: finishReason);
  }

  bool _looksLikeTruncatedJson(String value) {
    final normalized = _stripMarkdownFence(value.trim());
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

    if (_hasUnterminatedQuotedString(normalized, firstBrace)) {
      return true;
    }

    final trimmed = normalized.trimRight();
    return trimmed.endsWith(':') || trimmed.endsWith(',');
  }

  bool _hasUnterminatedQuotedString(String value, int startIndex) {
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

  GeminiTripPlan _parseBasePlanText({
    required String text,
    required String fallbackCountry,
  }) {
    final trimmed = text.trim();
    final normalized = _stripMarkdownFence(trimmed);
    final decoded = _extractEmbeddedMap(normalized);
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

    return _planFromMap(
      decoded: decoded,
      fallbackCountry: fallbackCountry,
      rawText: text,
    );
  }

  GeminiTripPlan _planFromMap({
    required Map<String, dynamic> decoded,
    required String fallbackCountry,
    required String rawText,
  }) {
    final country = _readString(decoded['country']) ?? fallbackCountry;
    final summary = _readString(decoded['summary']) ?? '';
    final stayDuration = _readStayDuration(decoded['duration']);
    final timeWindows = _readTimeWindows(decoded['time_windows']);
    final cityPlan = _readCityPlan(decoded['city_plan']);
    final cityDetailsFromPayload = _readCityDetails(decoded['city_cards']);
    final cityDetails = _alignCityDetails(
      cityPlan: cityPlan,
      details: cityDetailsFromPayload,
    );

    return GeminiTripPlan(
      country: country,
      summary: summary,
      stayDuration: stayDuration,
      timeWindows: timeWindows,
      cityPlan: cityPlan,
      cityDetails: cityDetails,
      rawText: rawText,
    );
  }

  Map<String, dynamic>? _extractEmbeddedMap(String value) {
    final firstBrace = value.indexOf('{');
    final lastBrace = value.lastIndexOf('}');
    if (firstBrace == -1 || lastBrace == -1 || lastBrace <= firstBrace) {
      return null;
    }
    final jsonText = value.substring(firstBrace, lastBrace + 1);
    final decoded = _tryDecodeJson(jsonText);
    if (decoded is! Map<String, dynamic>) {
      return null;
    }
    return decoded;
  }

  List<GeminiCityDetail> _parseCityDetailsText({
    required String text,
    required List<GeminiCityPlan> cityPlan,
  }) {
    final normalized = _stripMarkdownFence(text.trim());
    final decoded = _extractEmbeddedMap(normalized);
    if (decoded == null) {
      return _alignCityDetails(
        cityPlan: cityPlan,
        details: const <GeminiCityDetail>[],
      );
    }
    final details = _readCityDetails(decoded['city_cards']);
    return _alignCityDetails(cityPlan: cityPlan, details: details);
  }

  Future<List<GeminiCityDetail>> _attachOpenImages({
    required List<GeminiCityDetail> cityDetails,
    required String countryName,
    bool onlyMissingImages = false,
  }) async {
    if (cityDetails.isEmpty) {
      return const <GeminiCityDetail>[];
    }

    final imageFutures = cityDetails.map((detail) async {
      if (onlyMissingImages && detail.image != null) {
        return detail;
      }
      final image = await _findOpenImageForCity(
        city: detail.city,
        countryName: countryName,
        imageQuery: detail.imageQuery,
      );
      if (image == null) {
        return detail;
      }
      return detail.copyWith(image: image);
    }).toList(growable: false);

    return Future.wait(imageFutures);
  }

  Future<GeminiCityImage?> _findOpenImageForCity({
    required String city,
    required String countryName,
    required String imageQuery,
  }) async {
    final queryQueue = <String>[
      imageQuery,
      '$city skyline $countryName',
      '$city downtown $countryName',
      '$city cityscape',
    ];
    final tried = <String>{};

    for (final rawQuery in queryQueue) {
      final query = rawQuery.trim();
      if (query.isEmpty || !tried.add(query.toLowerCase())) {
        continue;
      }
      final results = await _searchOpenverse(query);
      final image = _pickBestOpenverseResult(results);
      if (image != null) {
        return image;
      }
    }

    return null;
  }

  Future<List<Map<String, dynamic>>> _searchOpenverse(String query) async {
    final uri = Uri.https(
      'api.openverse.org',
      '/v1/images/',
      <String, String>{
        'q': query,
        'license': 'cc0,by,by-sa',
        'mature': 'false',
        'page_size': '8',
      },
    );

    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 10);
    try {
      final request = await client.getUrl(uri);
      final response = await request.close();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return const <Map<String, dynamic>>[];
      }
      final rawBody = await response.transform(utf8.decoder).join();
      final decoded = _tryDecodeJson(rawBody);
      if (decoded is! Map<String, dynamic>) {
        return const <Map<String, dynamic>>[];
      }
      final rawResults = decoded['results'];
      if (rawResults is! List) {
        return const <Map<String, dynamic>>[];
      }
      final parsed = <Map<String, dynamic>>[];
      for (final item in rawResults) {
        if (item is Map<String, dynamic>) {
          parsed.add(item);
        }
      }
      return parsed;
    } catch (_) {
      return const <Map<String, dynamic>>[];
    } finally {
      client.close(force: true);
    }
  }

  GeminiCityImage? _pickBestOpenverseResult(
      List<Map<String, dynamic>> results) {
    for (final item in results) {
      final imageUrl = _readString(item['url']);
      if (imageUrl == null || !_isDisplayableImageUrl(imageUrl)) {
        continue;
      }
      final sourcePageUrl = _readString(item['foreign_landing_url']) ?? '';
      final title = _readString(item['title']) ?? 'City image';
      final creator = _readString(item['creator']) ?? 'Unknown creator';
      final licenseRaw = _readString(item['license']) ?? 'unknown';
      final licenseVersion = _readString(item['license_version']);
      final license = licenseVersion == null || licenseVersion.isEmpty
          ? licenseRaw
          : '$licenseRaw-$licenseVersion';
      final licenseUrl = _readString(item['license_url']) ?? '';
      final source = _readString(item['source']) ?? 'openverse';

      return GeminiCityImage(
        imageUrl: imageUrl,
        sourcePageUrl: sourcePageUrl,
        title: title,
        creator: creator,
        license: license,
        licenseUrl: licenseUrl,
        source: source,
      );
    }
    return null;
  }

  bool _isDisplayableImageUrl(String url) {
    final path = (Uri.tryParse(url)?.path ?? url).toLowerCase();
    if (path.endsWith('.svg') || path.endsWith('.gif')) {
      return false;
    }
    return true;
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

  GeminiStayDuration? _readStayDuration(dynamic raw) {
    if (raw is! Map<String, dynamic>) {
      return null;
    }
    final days = _readInt(raw['days']);
    final reason = _readString(raw['reason']);
    if (days == null || reason == null) {
      return null;
    }
    final source =
        _readString(raw['source'])?.toLowerCase() ?? 'ai_recommended';
    final normalizedSource =
        source == 'user_selected' ? 'user_selected' : 'ai_recommended';
    return GeminiStayDuration(
      days: days.clamp(1, 45),
      reason: reason,
      source: normalizedSource,
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
      final isExtra = _readBool(item['is_extra']) ?? false;
      if (city == null || days == null || reason == null) {
        continue;
      }
      parsed.add(
        GeminiCityPlan(
          city: city,
          days: days.clamp(1, 30),
          reason: reason,
          isExtra: isExtra,
        ),
      );
    }
    return parsed;
  }

  List<GeminiCityDetail> _readCityDetails(dynamic raw) {
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

      final overview = _readString(item['overview']) ?? '';
      final imageQuery = _readString(item['image_query']) ?? '$city skyline';
      final timeline = _readTimeline(item['timeline']);
      final thingsToDo = _readStringList(item['things_to_do']);
      final image = _readCityImage(item['image']);

      parsed.add(
        GeminiCityDetail(
          city: city,
          overview: overview,
          imageQuery: imageQuery,
          timeline: timeline,
          thingsToDo: thingsToDo,
          image: image,
        ),
      );
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
      parsed.add(
        GeminiTimelineStop(
          slot: slot,
          place: place,
          note: note,
        ),
      );
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

  String? _readNonEmpty(String? value) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    return normalized;
  }

  bool _isValidStayDuration(GeminiStayDuration? value) {
    return value != null && value.days > 0;
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

class _GeminiTextPayload {
  const _GeminiTextPayload({
    required this.text,
    required this.finishReason,
  });

  final String? text;
  final String finishReason;
}
