import 'dart:convert';
import 'dart:io';

import '../../config/runtime_config.dart';
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

  Future<void> syncProfile({
    required String accessToken,
    required SocialProfileSnapshot profile,
  }) async {
    await _requestJson(
      method: 'PUT',
      path: '/v1/social/me/profile',
      accessToken: accessToken,
      body: profile.toJson(),
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
      request.write(jsonEncode(body));
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
