import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;

import '../../config/runtime_config.dart';
import 'social_asset_urls.dart';
import 'social_models.dart';

class SocialApiClient {
  SocialApiClient({
    HttpClient? httpClient,
    String? baseUrl,
  })  : _httpClient = httpClient ??
            (HttpClient()..connectionTimeout = const Duration(seconds: 12)),
        _baseUri = _parseBaseUri(baseUrl);

  final HttpClient _httpClient;
  final Uri _baseUri;

  static Uri _parseBaseUri(String? rawBaseUrl) {
    final normalized = (rawBaseUrl ?? defaultSteppedApiBaseUrl).trim();
    final parsed = Uri.tryParse(normalized);
    if (parsed != null && parsed.hasScheme && parsed.host.isNotEmpty) {
      return parsed;
    }

    if (rawBaseUrl == null) {
      return Uri.parse(defaultSteppedApiBaseUrl);
    }

    if (rawBaseUrl.trim().isNotEmpty) {
      throw const SocialApiException(
        'API base URL is invalid. Set STEPPED_API_BASE_URL to a full URL.',
      );
    }

    return Uri.parse(defaultSteppedApiBaseUrl);
  }

  Future<SocialProfileSnapshot> syncProfile({
    required String accessToken,
    required SocialProfileSnapshot profile,
  }) async {
    final payload = await _requestJson(
      method: 'PUT',
      path: '/v1/social/me/profile',
      accessToken: accessToken,
      body: profile.toJson(),
    );
    return SocialProfileSnapshot.fromJson(payload);
  }

  Future<String> uploadProfilePhoto({
    required String accessToken,
    required String filePath,
  }) async {
    final json = await _uploadMediaFile(
      accessToken: accessToken,
      filePath: filePath,
      apiPath: '/v1/social/me/profile-photo',
      emptySelectionMessage: 'Choose a profile photo first.',
      missingFileMessage:
          'Selected profile photo could not be found on this device.',
      unsupportedTypeMessage:
          'Unsupported profile photo type. Use JPEG, PNG, WEBP, GIF, HEIC, or HEIF.',
      boundaryPrefix: 'stepped-profile-photo',
    );
    final photoUrl =
        normalizeSocialAssetUrl(_firstNonEmptyString(<dynamic>[json['photo_url']]));
    if (photoUrl != null && photoUrl.isNotEmpty) {
      return photoUrl;
    }
    throw const SocialApiException(
      'The social server returned an invalid profile photo URL.',
    );
  }

  Future<String> uploadTripCoverPhoto({
    required String accessToken,
    required String tripId,
    required String filePath,
  }) async {
    final json = await _uploadMediaFile(
      accessToken: accessToken,
      filePath: filePath,
      apiPath: '/v1/social/me/trips/${Uri.encodeComponent(tripId)}/cover-photo',
      emptySelectionMessage: 'Choose a trip cover image first.',
      missingFileMessage:
          'Selected trip cover image could not be found on this device.',
      unsupportedTypeMessage:
          'Unsupported trip cover image type. Use JPEG, PNG, WEBP, GIF, HEIC, or HEIF.',
      boundaryPrefix: 'stepped-trip-cover',
    );
    final imageUrl = normalizeSocialAssetUrl(
      _firstNonEmptyString(<dynamic>[
        json['cover_image_url'],
        json['image_url'],
      ]),
    );
    if (imageUrl != null && imageUrl.isNotEmpty) {
      return imageUrl;
    }
    throw const SocialApiException(
      'The social server returned an invalid trip cover image URL.',
    );
  }

  Future<String> uploadTripCityPhoto({
    required String accessToken,
    required String tripId,
    required String cityKey,
    required String filePath,
  }) async {
    final json = await _uploadMediaFile(
      accessToken: accessToken,
      filePath: filePath,
      apiPath:
          '/v1/social/me/trips/${Uri.encodeComponent(tripId)}/cities/${Uri.encodeComponent(cityKey)}/photo',
      emptySelectionMessage: 'Choose a city image first.',
      missingFileMessage:
          'Selected city image could not be found on this device.',
      unsupportedTypeMessage:
          'Unsupported city image type. Use JPEG, PNG, WEBP, GIF, HEIC, or HEIF.',
      boundaryPrefix: 'stepped-trip-city',
    );
    final imageUrl = normalizeSocialAssetUrl(
      _firstNonEmptyString(<dynamic>[
        json['imageUri'],
        json['image_url'],
      ]),
    );
    if (imageUrl != null && imageUrl.isNotEmpty) {
      return imageUrl;
    }
    throw const SocialApiException(
      'The social server returned an invalid city image URL.',
    );
  }

  Future<String> uploadWishlistPhoto({
    required String accessToken,
    required String wishlistItemId,
    required String filePath,
  }) async {
    final json = await _uploadMediaFile(
      accessToken: accessToken,
      filePath: filePath,
      apiPath:
          '/v1/social/me/wishlist/${Uri.encodeComponent(wishlistItemId)}/photo',
      emptySelectionMessage: 'Choose a wishlist image first.',
      missingFileMessage:
          'Selected wishlist image could not be found on this device.',
      unsupportedTypeMessage:
          'Unsupported wishlist image type. Use JPEG, PNG, WEBP, GIF, HEIC, or HEIF.',
      boundaryPrefix: 'stepped-wishlist-photo',
    );
    final imageUrl =
        normalizeSocialAssetUrl(_firstNonEmptyString(<dynamic>[json['image_url']]));
    if (imageUrl != null && imageUrl.isNotEmpty) {
      return imageUrl;
    }
    throw const SocialApiException(
      'The social server returned an invalid wishlist image URL.',
    );
  }

  Future<Map<String, dynamic>> _uploadMediaFile({
    required String accessToken,
    required String filePath,
    required String apiPath,
    required String emptySelectionMessage,
    required String missingFileMessage,
    required String unsupportedTypeMessage,
    required String boundaryPrefix,
  }) async {
    final normalizedPath = filePath.trim();
    if (normalizedPath.isEmpty) {
      throw SocialApiException(emptySelectionMessage);
    }

    final file = File(normalizedPath);
    if (!await file.exists()) {
      throw SocialApiException(missingFileMessage);
    }

    final mimeType = _mimeTypeForFile(normalizedPath);
    if (mimeType == null) {
      throw SocialApiException(unsupportedTypeMessage);
    }

    final boundary =
        '----$boundaryPrefix-${DateTime.now().microsecondsSinceEpoch}';
    final uri = _buildUri(apiPath);
    HttpClientRequest request;
    try {
      request = await _httpClient.openUrl('POST', uri);
    } on SocketException {
      throw const SocialApiException(
        'Could not reach the social server. Check your internet connection.',
      );
    } on HandshakeException {
      throw const SocialApiException(
        'Secure connection to the social server failed.',
      );
    }

    request.headers.set(HttpHeaders.acceptHeader, 'application/json');
    request.headers.set(
      HttpHeaders.authorizationHeader,
      'Bearer ${accessToken.trim()}',
    );
    request.headers.set(
      HttpHeaders.contentTypeHeader,
      'multipart/form-data; boundary=$boundary',
    );

    final fileName = path.basename(normalizedPath);
    final header = StringBuffer()
      ..write('--$boundary\r\n')
      ..write(
        'Content-Disposition: form-data; name="file"; filename="$fileName"\r\n',
      )
      ..write('Content-Type: $mimeType\r\n\r\n');
    request.write(header.toString());
    await request.addStream(file.openRead());
    request.write('\r\n--$boundary--\r\n');

    HttpClientResponse response;
    try {
      response = await request.close();
    } on SocketException {
      throw const SocialApiException(
        'Connection to the social server was interrupted.',
      );
    }

    final rawBody = await response.transform(utf8.decoder).join();
    final decoded = _decodeJsonOrNull(rawBody);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return _asMap(decoded ?? <String, dynamic>{});
    }

    final message = _extractErrorMessage(decoded) ??
        _defaultErrorMessageForStatus(
          statusCode: response.statusCode,
          path: apiPath,
        );
    throw SocialApiException(
      message,
      statusCode: response.statusCode,
    );
  }

  Future<void> syncTravel({
    required String accessToken,
    required SocialTravelSnapshot travel,
  }) async {
    await _requestJson(
      method: 'PUT',
      path: '/v1/social/me/travel',
      accessToken: accessToken,
      body: travel.toJson(),
    );
  }

  Future<void> syncWishlist({
    required String accessToken,
    required SocialWishlistSnapshot wishlist,
  }) async {
    await _requestJson(
      method: 'PUT',
      path: '/v1/social/me/wishlist',
      accessToken: accessToken,
      body: wishlist.toJson(),
    );
  }

  Future<SocialMeData> getCurrentSocialState({
    required String accessToken,
  }) async {
    final payload = await _requestJson(
      method: 'GET',
      path: '/v1/social/me',
      accessToken: accessToken,
    );
    return SocialMeData.fromJson(payload);
  }

  Future<SocialPrivacySettings> getMyPrivacy({
    required String accessToken,
  }) async {
    final payload = await _requestJson(
      method: 'GET',
      path: '/v1/social/me/privacy',
      accessToken: accessToken,
    );
    return SocialPrivacySettings.fromJson(payload);
  }

  Future<SocialPrivacySettings> updateMyPrivacy({
    required String accessToken,
    required bool shareWishlistWithFriends,
  }) async {
    final payload = await _requestJson(
      method: 'PUT',
      path: '/v1/social/me/privacy',
      accessToken: accessToken,
      body: <String, dynamic>{
        'share_wishlist_with_friends': shareWishlistWithFriends,
      },
    );
    return SocialPrivacySettings.fromJson(payload);
  }

  Future<SocialInviteLink> createFriendLink({
    required String accessToken,
  }) async {
    final payload = await _requestJson(
      method: 'POST',
      path: '/v1/social/friend-links',
      accessToken: accessToken,
    );
    final json = _asMap(payload);
    return SocialInviteLink.fromJson(json['invite'] ?? json);
  }

  Future<void> deleteFriendLink({
    required String accessToken,
    required String token,
  }) async {
    await _requestJson(
      method: 'DELETE',
      path: '/v1/social/friend-links/$token',
      accessToken: accessToken,
    );
  }

  Future<FriendInvitePreview> getFriendLinkPreview({
    required String accessToken,
    required String token,
  }) async {
    final payload = await _requestJson(
      method: 'GET',
      path: '/v1/social/friend-links/$token',
      accessToken: accessToken,
    );
    return FriendInvitePreview.fromJson(payload, token);
  }

  Future<FriendAcceptResult> acceptFriendLink({
    required String accessToken,
    required String token,
  }) async {
    final payload = await _requestJson(
      method: 'POST',
      path: '/v1/social/friend-links/$token/accept',
      accessToken: accessToken,
    );
    return FriendAcceptResult.fromJson(payload);
  }

  Future<List<FriendSummary>> getFriends({
    required String accessToken,
  }) async {
    final payload = await _requestJson(
      method: 'GET',
      path: '/v1/social/friends',
      accessToken: accessToken,
    );
    final json = _asMap(payload);
    final rawFriends = json['friends'];
    if (rawFriends is! List) {
      return const <FriendSummary>[];
    }
    return <FriendSummary>[
      for (final entry in rawFriends) FriendSummary.fromJson(entry),
    ];
  }

  Future<FriendProfileResponse> getFriendProfile({
    required String accessToken,
    required String friendUserId,
  }) async {
    final payload = await _requestJson(
      method: 'GET',
      path: '/v1/social/friends/$friendUserId',
      accessToken: accessToken,
    );
    return FriendProfileResponse.fromJson(payload);
  }

  Future<void> deleteFriend({
    required String accessToken,
    required String friendUserId,
  }) async {
    await _requestJson(
      method: 'DELETE',
      path: '/v1/social/friends/$friendUserId',
      accessToken: accessToken,
    );
  }

  Future<dynamic> _requestJson({
    required String method,
    required String path,
    required String accessToken,
    Object? body,
  }) async {
    final uri = _buildUri(path);
    HttpClientRequest request;
    try {
      request = await _httpClient.openUrl(method, uri);
    } on SocketException {
      throw const SocialApiException(
        'Could not reach the social server. Check your internet connection.',
      );
    } on HandshakeException {
      throw const SocialApiException(
        'Secure connection to the social server failed.',
      );
    }

    request.headers.set(HttpHeaders.acceptHeader, 'application/json');
    request.headers.set(
      HttpHeaders.authorizationHeader,
      'Bearer ${accessToken.trim()}',
    );

    if (body != null) {
      request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
      request.add(utf8.encode(jsonEncode(body)));
    }

    HttpClientResponse response;
    try {
      response = await request.close();
    } on SocketException {
      throw const SocialApiException(
        'Connection to the social server was interrupted.',
      );
    }

    final rawBody = await response.transform(utf8.decoder).join();
    final decoded = _decodeJsonOrNull(rawBody);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decoded ?? <String, dynamic>{};
    }

    final message = _extractErrorMessage(decoded) ??
        _defaultErrorMessageForStatus(
          statusCode: response.statusCode,
          path: path,
        );
    throw SocialApiException(
      message,
      statusCode: response.statusCode,
    );
  }

  Uri _buildUri(String rawPath) {
    final normalizedPath = rawPath.startsWith('/') ? rawPath : '/$rawPath';
    final basePath = _baseUri.path.endsWith('/')
        ? _baseUri.path.substring(0, _baseUri.path.length - 1)
        : _baseUri.path;
    return _baseUri.replace(path: '$basePath$normalizedPath');
  }

  static dynamic _decodeJsonOrNull(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    try {
      return jsonDecode(trimmed);
    } catch (_) {
      return null;
    }
  }

  static Map<String, dynamic> _asMap(dynamic raw) {
    if (raw is Map<String, dynamic>) {
      return raw;
    }
    if (raw is Map) {
      return <String, dynamic>{
        for (final entry in raw.entries) '${entry.key}': entry.value,
      };
    }
    throw const SocialApiException(
      'The social server returned an invalid payload.',
    );
  }

  static String? _firstNonEmptyString(List<dynamic> values) {
    for (final value in values) {
      if (value is! String) {
        continue;
      }
      final normalized = value.trim();
      if (normalized.isNotEmpty) {
        return normalized;
      }
    }
    return null;
  }

  static String? _extractErrorMessage(dynamic decoded) {
    if (decoded is! Map) {
      return null;
    }
    for (final key in <String>[
      'message',
      'error_description',
      'error',
      'detail',
    ]) {
      final value = decoded[key];
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return null;
  }

  String _defaultErrorMessageForStatus({
    required int statusCode,
    required String path,
  }) {
    final normalizedPath = path.trim().toLowerCase();
    if (statusCode == HttpStatus.unauthorized) {
      return 'You need to sign in again to use social features.';
    }
    if (statusCode == HttpStatus.notFound &&
        normalizedPath.startsWith('/v1/social/friend-links/')) {
      return 'This invite link could not be found.';
    }
    if (statusCode == HttpStatus.forbidden &&
        normalizedPath.startsWith('/v1/social/friends/')) {
      return 'This profile is only available to confirmed friends.';
    }
    if (statusCode == HttpStatus.notFound &&
        normalizedPath.startsWith('/v1/social/friends/')) {
      return 'This friend could not be found.';
    }
    return 'Social request failed ($statusCode).';
  }

  static String? _mimeTypeForFile(String filePath) {
    switch (path.extension(filePath).toLowerCase()) {
      case '.jpg':
      case '.jpeg':
        return 'image/jpeg';
      case '.png':
        return 'image/png';
      case '.webp':
        return 'image/webp';
      case '.gif':
        return 'image/gif';
      case '.heic':
        return 'image/heic';
      case '.heif':
        return 'image/heif';
      default:
        return null;
    }
  }
}

class SocialApiException implements Exception {
  const SocialApiException(
    this.message, {
    this.statusCode,
  });

  final String message;
  final int? statusCode;

  bool get isUnauthorized => statusCode == HttpStatus.unauthorized;
  bool get isNotFound => statusCode == HttpStatus.notFound;
  bool get isForbidden => statusCode == HttpStatus.forbidden;
  bool get isConflict => statusCode == HttpStatus.conflict;

  @override
  String toString() => message;
}
