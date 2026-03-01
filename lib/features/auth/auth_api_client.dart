import 'dart:convert';
import 'dart:io';

import '../../config/runtime_config.dart';
import 'auth_user.dart';

class AuthApiClient {
  AuthApiClient({
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
      throw const AuthApiException(
        'API base URL is invalid. Set STEPPED_API_BASE_URL to a full URL.',
      );
    }

    return Uri.parse(defaultSteppedApiBaseUrl);
  }

  Future<AuthApiSession> registerWithEmail({
    required String displayName,
    required String email,
    required String password,
  }) async {
    return _postSession(
      '/v1/auth/register',
      <String, dynamic>{
        'display_name': displayName.trim(),
        'email': email.trim().toLowerCase(),
        'password': password,
      },
      fallbackProvider: AuthProvider.password,
    );
  }

  Future<AuthApiSession> signInWithEmail({
    required String email,
    required String password,
  }) async {
    return _postSession(
      '/v1/auth/sign-in',
      <String, dynamic>{
        'email': email.trim().toLowerCase(),
        'password': password,
      },
      fallbackProvider: AuthProvider.password,
    );
  }

  Future<AuthApiSession> signInWithGoogle({
    required String idToken,
    required String email,
    required String displayName,
    String? photoUrl,
  }) async {
    return _postSession(
      '/v1/auth/google',
      <String, dynamic>{
        'id_token': idToken,
        'email': email.trim().toLowerCase(),
        'display_name': displayName.trim(),
        if (photoUrl != null && photoUrl.trim().isNotEmpty)
          'photo_url': photoUrl.trim(),
      },
      fallbackProvider: AuthProvider.google,
    );
  }

  Future<AuthUser> fetchCurrentUser({
    required String accessToken,
  }) async {
    final payload = await _requestJson(
      method: 'GET',
      path: '/v1/auth/me',
      headers: <String, String>{
        HttpHeaders.authorizationHeader: 'Bearer $accessToken',
      },
    );
    final json = _asMap(payload);
    final userRaw = json['user'] ?? json;
    return _parseUser(userRaw, fallbackProvider: AuthProvider.password);
  }

  Future<AuthApiSession> _postSession(
    String path,
    Map<String, dynamic> body, {
    required AuthProvider fallbackProvider,
  }) async {
    final payload = await _requestJson(
      method: 'POST',
      path: path,
      body: body,
    );
    final json = _asMap(payload);
    final token = _firstNonEmptyString(<dynamic>[
      json['access_token'],
      json['token'],
      json['session_token'],
      if (json['data'] is Map) (json['data'] as Map)['access_token'],
      if (json['data'] is Map) (json['data'] as Map)['token'],
    ]);
    if (token == null) {
      throw const AuthApiException(
          'The auth server returned no session token.');
    }

    final userRaw = json['user'] ??
        (json['data'] is Map ? (json['data'] as Map)['user'] : null);
    final user = _parseUser(userRaw, fallbackProvider: fallbackProvider);
    return AuthApiSession(
      accessToken: token,
      user: user,
    );
  }

  Future<dynamic> _requestJson({
    required String method,
    required String path,
    Map<String, String>? headers,
    Object? body,
  }) async {
    final uri = _buildUri(path);
    HttpClientRequest request;
    try {
      request = await _httpClient.openUrl(method, uri);
    } on SocketException {
      throw const AuthApiException(
        'Could not reach the auth server. Check your internet connection.',
      );
    } on HandshakeException {
      throw const AuthApiException(
        'Secure connection to the auth server failed.',
      );
    }

    request.headers.set(HttpHeaders.acceptHeader, 'application/json');
    if (headers != null) {
      for (final entry in headers.entries) {
        request.headers.set(entry.key, entry.value);
      }
    }

    if (body != null) {
      request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
      request.write(jsonEncode(body));
    }

    HttpClientResponse response;
    try {
      response = await request.close();
    } on SocketException {
      throw const AuthApiException(
        'Connection to the auth server was interrupted.',
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
    throw AuthApiException(
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

  static AuthUser _parseUser(
    dynamic raw, {
    required AuthProvider fallbackProvider,
  }) {
    final parsed = AuthUser.fromJson(raw);
    if (parsed != null) {
      return parsed;
    }

    final json = _asMap(raw);
    final id = _firstNonEmptyString(<dynamic>[json['id'], json['user_id']]);
    final email = _firstNonEmptyString(<dynamic>[json['email']]);
    final displayName = _firstNonEmptyString(<dynamic>[
      json['display_name'],
      json['displayName'],
      json['name'],
    ]);
    final providerRaw = _firstNonEmptyString(<dynamic>[json['provider']]);
    final provider = AuthProviderX.fromName(providerRaw) ?? fallbackProvider;
    final photoUrl = _firstNonEmptyString(<dynamic>[
      json['photo_url'],
      json['photoUrl'],
      json['picture'],
    ]);

    if (id == null || email == null || displayName == null) {
      throw const AuthApiException('The auth server returned an invalid user.');
    }

    return AuthUser(
      id: id,
      email: email,
      displayName: displayName,
      provider: provider,
      photoUrl: photoUrl,
    );
  }

  static Map<String, dynamic> _asMap(dynamic raw) {
    if (raw is Map<String, dynamic>) {
      return raw;
    }
    if (raw is Map) {
      final map = <String, dynamic>{};
      for (final entry in raw.entries) {
        map['${entry.key}'] = entry.value;
      }
      return map;
    }
    throw const AuthApiException(
        'The auth server returned an invalid payload.');
  }

  static String? _extractErrorMessage(dynamic decoded) {
    if (decoded is! Map) {
      return null;
    }
    return _firstNonEmptyString(<dynamic>[
      decoded['message'],
      decoded['error_description'],
      decoded['error'],
    ]);
  }

  String _defaultErrorMessageForStatus({
    required int statusCode,
    required String path,
  }) {
    if (statusCode == HttpStatus.notFound && _looksLikeAuthRoute(path)) {
      return 'Authentication is not deployed on this API yet (404). Deploy the latest backend auth routes or point STEPPED_API_BASE_URL to the correct auth API.';
    }
    return 'Auth request failed ($statusCode).';
  }

  bool _looksLikeAuthRoute(String path) {
    final normalized = path.trim().toLowerCase();
    return normalized.startsWith('/v1/auth/');
  }

  static String? _firstNonEmptyString(List<dynamic> values) {
    for (final value in values) {
      if (value is! String) {
        continue;
      }
      final text = value.trim();
      if (text.isNotEmpty) {
        return text;
      }
    }
    return null;
  }
}

class AuthApiSession {
  const AuthApiSession({
    required this.accessToken,
    required this.user,
  });

  final String accessToken;
  final AuthUser user;
}

class AuthApiException implements Exception {
  const AuthApiException(
    this.message, {
    this.statusCode,
  });

  final String message;
  final int? statusCode;

  bool get isUnauthorized => statusCode == HttpStatus.unauthorized;

  @override
  String toString() => message;
}
