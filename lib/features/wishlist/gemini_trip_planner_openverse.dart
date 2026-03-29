import 'dart:convert';
import 'dart:io';

import 'gemini_trip_models.dart';

Future<List<GeminiCityDetail>> attachOpenverseImagesToGeminiCityDetails({
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
    final image = await findOpenverseImageForCity(
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

Future<GeminiCityImage?> findOpenverseImageForCity({
  required String city,
  required String countryName,
  String? imageQuery,
}) async {
  final normalizedQuery = (imageQuery == null || imageQuery.trim().isEmpty)
      ? '$city skyline'
      : imageQuery.trim();
  final queryQueue = <String>[
    normalizedQuery,
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

String buildWishlistCoverImageQuery({
  required String title,
  required String countryName,
  String? purpose,
  String? summary,
  List<String> cityHints = const <String>[],
  List<String> cityImageQueries = const <String>[],
}) {
  final normalizedPurpose = _normalizeWishlistSearchSeed(purpose);
  final normalizedSummary = _normalizeWishlistSearchSeed(summary);
  final normalizedTitle = _normalizeWishlistSearchSeed(title);
  final normalizedCountry = countryName.trim();
  final primaryCityHint = cityImageQueries
      .map(_normalizeWishlistSearchSeed)
      .firstWhere(
        (value) => value.isNotEmpty,
        orElse: () => cityHints
            .map(_normalizeWishlistSearchSeed)
            .firstWhere((value) => value.isNotEmpty, orElse: () => ''),
      );

  if (normalizedPurpose.isNotEmpty && normalizedCountry.isNotEmpty) {
    return '$normalizedPurpose $normalizedCountry';
  }
  if (normalizedPurpose.isNotEmpty) {
    return normalizedPurpose;
  }
  if (primaryCityHint.isNotEmpty && normalizedCountry.isNotEmpty) {
    return '$primaryCityHint $normalizedCountry';
  }
  if (normalizedSummary.isNotEmpty && normalizedCountry.isNotEmpty) {
    return '$normalizedSummary $normalizedCountry';
  }
  if (normalizedTitle.isNotEmpty && normalizedCountry.isNotEmpty) {
    return '$normalizedTitle $normalizedCountry';
  }
  if (normalizedTitle.isNotEmpty) {
    return normalizedTitle;
  }
  if (normalizedCountry.isNotEmpty) {
    return '$normalizedCountry travel landscape';
  }
  return 'travel destination landscape';
}

Future<GeminiCityImage?> findOpenverseImageForWishlistCover({
  required String title,
  required String countryName,
  String? purpose,
  String? summary,
  List<String> cityHints = const <String>[],
  List<String> cityImageQueries = const <String>[],
}) async {
  final normalizedTitle = _normalizeWishlistSearchSeed(title);
  final normalizedPurpose = _normalizeWishlistSearchSeed(purpose);
  final normalizedSummary = _normalizeWishlistSearchSeed(summary);
  final normalizedCountry = countryName.trim();
  final normalizedCityHints = cityHints
      .map(_normalizeWishlistSearchSeed)
      .where((value) => value.isNotEmpty)
      .toList(growable: false);
  final normalizedCityQueries = cityImageQueries
      .map(_normalizeWishlistSearchSeed)
      .where((value) => value.isNotEmpty)
      .toList(growable: false);
  final primaryQuery = buildWishlistCoverImageQuery(
    title: title,
    countryName: countryName,
    purpose: purpose,
    summary: summary,
    cityHints: cityHints,
    cityImageQueries: cityImageQueries,
  );
  final queryQueue = <String>[
    primaryQuery,
    ...normalizedCityQueries.take(2).map((query) => '$query $normalizedCountry'),
    ...normalizedCityHints.take(2).map((query) => '$query $normalizedCountry'),
    if (normalizedPurpose.isNotEmpty && normalizedCountry.isNotEmpty)
      '$normalizedPurpose experience $normalizedCountry',
    if (normalizedSummary.isNotEmpty && normalizedCountry.isNotEmpty)
      '$normalizedSummary $normalizedCountry',
    if (normalizedTitle.isNotEmpty && normalizedCountry.isNotEmpty)
      '$normalizedTitle destination $normalizedCountry',
    if (normalizedPurpose.isNotEmpty) normalizedPurpose,
    if (normalizedCountry.isNotEmpty) '$normalizedCountry scenic landscape',
    if (normalizedCountry.isNotEmpty) '$normalizedCountry travel',
  ];

  return _findOpenverseImageForQueries(queryQueue);
}

Future<GeminiCityImage?> _findOpenverseImageForQueries(
  List<String> queryQueue,
) async {
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

  final client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
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

GeminiCityImage? _pickBestOpenverseResult(List<Map<String, dynamic>> results) {
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

dynamic _tryDecodeJson(String raw) {
  try {
    return jsonDecode(raw);
  } catch (_) {
    return null;
  }
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

String _normalizeWishlistSearchSeed(String? raw) {
  if (raw == null) {
    return '';
  }
  final normalized = raw
      .replaceAll(RegExp(r'[\r\n]+'), ' ')
      .replaceAll(RegExp(r'[^A-Za-z0-9\\s\\-]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  if (normalized.isEmpty) {
    return '';
  }
  final parts = normalized
      .split(RegExp(r'\s+'))
      .map((part) => part.trim())
      .where((part) => part.isNotEmpty)
      .take(8)
      .toList(growable: false);
  return parts.join(' ');
}
