import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'gemini_trip_planner.dart';

class CloudTripPlannerException implements Exception {
  const CloudTripPlannerException(this.message);

  final String message;

  @override
  String toString() => message;
}

final cloudTripPlannerClientProvider = Provider<CloudTripPlannerClient>((ref) {
  return CloudTripPlannerClient(
    localPlanner: ref.watch(geminiTripPlannerProvider),
  );
});

class CloudTripPlannerClient {
  const CloudTripPlannerClient({
    required GeminiTripPlanner localPlanner,
  }) : _localPlanner = localPlanner;

  final GeminiTripPlanner _localPlanner;

  Future<GeminiTripPlan> generatePlan({
    required String baseUrl,
    required String countryName,
    String? homeBase,
    DateTimeRange? preciseWindow,
    int? preferredMonth,
    GeminiDurationPreference? durationPreference,
    List<String>? preferredCities,
    bool allowAdditionalCitiesIfTimeAllows = false,
    int? maxOutputTokens,
  }) async {
    final normalizedBaseUrl = baseUrl.trim();
    if (normalizedBaseUrl.isEmpty) {
      throw const CloudTripPlannerException(
        'Missing Cloud API base URL. Add it in Settings first.',
      );
    }

    final normalizedCountryName = countryName.trim();
    if (normalizedCountryName.isEmpty) {
      throw const CloudTripPlannerException('Country is required.');
    }

    final uri = _buildTripPlannerUri(normalizedBaseUrl);
    final payload = <String, dynamic>{
      'country': normalizedCountryName,
      'home_base': homeBase?.trim(),
      'preferred_month': preferredMonth,
      'preferred_cities': (preferredCities ?? const <String>[])
          .map((city) => city.trim())
          .where((city) => city.isNotEmpty)
          .toList(growable: false),
      'allow_additional_cities': allowAdditionalCitiesIfTimeAllows,
      'max_output_tokens': maxOutputTokens,
      'duration_preference': durationPreference == null
          ? null
          : <String, dynamic>{
              'id': durationPreference.id,
              'min_days': durationPreference.minDays,
              'max_days': durationPreference.maxDays,
            },
      'precise_window': preciseWindow == null
          ? null
          : <String, String>{
              'start': _toIsoDate(preciseWindow.start),
              'end': _toIsoDate(preciseWindow.end),
            },
    };

    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 12);
    try {
      final request = await client.postUrl(uri);
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode(payload));

      final response = await request.close();
      final rawBody = await response.transform(utf8.decoder).join();
      final decoded = _tryDecodeJson(rawBody);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        final message = _extractErrorMessage(decoded) ??
            'Cloud planner failed (${response.statusCode}).';
        throw CloudTripPlannerException(message);
      }

      final responseMap = decoded is Map<String, dynamic> ? decoded : null;
      final planMap = _extractPlanMap(responseMap);
      if (planMap == null) {
        throw const CloudTripPlannerException(
          'Cloud planner returned an unexpected payload.',
        );
      }

      final parsed = _localPlanner.parseStoredPlan(
        jsonEncode(planMap),
        fallbackCountry: normalizedCountryName,
      );
      if (parsed == null) {
        throw const CloudTripPlannerException(
          'Cloud planner payload could not be parsed.',
        );
      }

      return parsed;
    } on SocketException {
      throw const CloudTripPlannerException(
        'Network error while contacting Cloud planner.',
      );
    } on HandshakeException {
      throw const CloudTripPlannerException(
        'TLS/SSL handshake failed while contacting Cloud planner.',
      );
    } on HttpException catch (error) {
      throw CloudTripPlannerException(error.message);
    } on FormatException {
      throw const CloudTripPlannerException(
        'Cloud planner response could not be parsed.',
      );
    } finally {
      client.close(force: true);
    }
  }

  Uri _buildTripPlannerUri(String baseUrl) {
    final parsed = Uri.tryParse(baseUrl);
    if (parsed == null || !parsed.hasScheme || !parsed.hasAuthority) {
      throw const CloudTripPlannerException(
        'Cloud API base URL is invalid.',
      );
    }

    final normalizedPath = parsed.path.endsWith('/')
        ? parsed.path.substring(0, parsed.path.length - 1)
        : parsed.path;
    final endpointPath = normalizedPath.isEmpty
        ? '/v1/ai/trip-plan'
        : '$normalizedPath/v1/ai/trip-plan';
    return parsed.replace(path: endpointPath);
  }

  Map<String, dynamic>? _extractPlanMap(Map<String, dynamic>? decoded) {
    if (decoded == null) {
      return null;
    }
    final nested = decoded['plan'];
    if (nested is Map<String, dynamic>) {
      return nested;
    }
    return decoded;
  }

  String? _extractErrorMessage(dynamic raw) {
    if (raw is! Map<String, dynamic>) {
      return null;
    }

    final message = raw['message'];
    if (message is String && message.trim().isNotEmpty) {
      return message.trim();
    }
    final error = raw['error'];
    if (error is String && error.trim().isNotEmpty) {
      return error.trim();
    }
    if (error is Map<String, dynamic>) {
      final nested = error['message'];
      if (nested is String && nested.trim().isNotEmpty) {
        return nested.trim();
      }
    }
    return null;
  }

  dynamic _tryDecodeJson(String raw) {
    try {
      return jsonDecode(raw);
    } catch (_) {
      return null;
    }
  }

  String _toIsoDate(DateTime value) {
    final year = value.year.toString().padLeft(4, '0');
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }
}
