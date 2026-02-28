import 'dart:convert';
import 'dart:io';

import 'gemini_trip_models.dart';
import 'gemini_trip_planner_parser.dart';

class GeminiPlannerRequestClient {
  const GeminiPlannerRequestClient({
    required this.models,
    required this.maxRetryOutputTokens,
  });

  final List<String> models;
  final int maxRetryOutputTokens;

  Future<String> requestText({
    required String apiKey,
    required String prompt,
    required double temperature,
    required int maxOutputTokens,
  }) async {
    GeminiPlannerException? lastMissingModelError;
    for (var index = 0; index < models.length; index += 1) {
      final model = models[index];
      try {
        return await _requestTextForModel(
          model: model,
          apiKey: apiKey,
          prompt: prompt,
          temperature: temperature,
          maxOutputTokens: maxOutputTokens,
        );
      } on GeminiPlannerException catch (error) {
        final isLast = index == models.length - 1;
        if (!isLast && _looksLikeMissingModel(error.message)) {
          lastMissingModelError = error;
          continue;
        }
        rethrow;
      }
    }
    throw lastMissingModelError ?? const GeminiPlannerException('Gemini request failed.');
  }

  Future<String> _requestTextForModel({
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
      if (maxOutputTokens < maxRetryOutputTokens)
        (maxOutputTokens * 2).clamp(maxOutputTokens + 1, maxRetryOutputTokens),
      if (maxRetryOutputTokens > (maxOutputTokens * 2)) maxRetryOutputTokens,
    ];

    final client = HttpClient()..connectionTimeout = const Duration(seconds: 15);
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
                <String, dynamic>{'text': prompt},
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
        final body = tryDecodeGeminiJson(rawBody);

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
          throw const GeminiPlannerException('Gemini returned an empty response.');
        }

        final hitTokenLimit =
            responsePayload.finishReason.toUpperCase() == 'MAX_TOKENS';
        final looksTruncated = looksLikeTruncatedGeminiJson(responseText);
        final shouldRetry =
            (hitTokenLimit || looksTruncated) && attempt < tokenBudgets.length - 1;
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

      throw const GeminiPlannerException('Gemini response could not be completed.');
    } on SocketException {
      throw const GeminiPlannerException('Network error while contacting Gemini.');
    } on HandshakeException {
      throw const GeminiPlannerException(
        'TLS/SSL handshake failed while contacting Gemini.',
      );
    } on HttpException catch (error) {
      throw GeminiPlannerException(error.message);
    } on FormatException {
      throw const GeminiPlannerException('Failed to parse Gemini response.');
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
        (readGeminiString(firstCandidate['finishReason']) ?? '').toUpperCase();
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
}

class _GeminiTextPayload {
  const _GeminiTextPayload({
    required this.text,
    required this.finishReason,
  });

  final String? text;
  final String finishReason;
}
