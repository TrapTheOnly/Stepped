import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'auth_api_client.dart';
import 'auth_user.dart';

const _sessionKey = 'stepped_auth_session_v2';

final authControllerProvider = ChangeNotifierProvider<AuthController>((ref) {
  final controller = AuthController();
  unawaited(controller.initialize());
  ref.onDispose(controller.dispose);
  return controller;
});

class AuthController extends ChangeNotifier {
  AuthController({
    GoogleSignIn? googleSignIn,
    AuthApiClient? authApiClient,
  })  : _googleSignIn = googleSignIn ?? GoogleSignIn.instance,
        _authApiClient = authApiClient ?? AuthApiClient();

  final GoogleSignIn _googleSignIn;
  final AuthApiClient _authApiClient;
  final String _serverClientId =
      const String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID');

  SharedPreferences? _preferences;
  AuthUser? _currentUser;
  String? _accessToken;
  bool _initialized = false;
  bool _isBusy = false;
  bool _googleInitialized = false;

  AuthUser? get currentUser => _currentUser;
  String? get accessToken => _accessToken;
  bool get isAuthenticated => _currentUser != null && _accessToken != null;
  bool get isInitialized => _initialized;
  bool get isBusy => _isBusy;

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    _setBusy(true, notify: false);
    try {
      _preferences = await SharedPreferences.getInstance();
      await _hydrateSessionFromDisk();
      await _refreshSessionFromBackend();
    } finally {
      _initialized = true;
      _setBusy(false, notify: false);
      notifyListeners();
    }
  }

  Future<void> registerWithEmail({
    required String displayName,
    required String email,
    required String password,
  }) async {
    await _ensureInitialized();
    final normalizedEmail = _normalizeEmail(email);
    final normalizedName = displayName.trim();

    if (normalizedName.length < 2) {
      throw const AuthException(
        'Use at least 2 characters for your display name.',
      );
    }
    if (!_isValidEmail(normalizedEmail)) {
      throw const AuthException('Enter a valid email address.');
    }
    if (password.length < 8) {
      throw const AuthException('Password should be at least 8 characters.');
    }

    await _runBusy(() async {
      final session = await _authApiClient.registerWithEmail(
        displayName: normalizedName,
        email: normalizedEmail,
        password: password,
      );
      await _setSession(
        accessToken: session.accessToken,
        user: session.user,
      );
    });
  }

  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    await _ensureInitialized();
    final normalizedEmail = _normalizeEmail(email);

    if (!_isValidEmail(normalizedEmail)) {
      throw const AuthException('Enter a valid email address.');
    }
    if (password.isEmpty) {
      throw const AuthException('Enter your password.');
    }

    await _runBusy(() async {
      final session = await _authApiClient.signInWithEmail(
        email: normalizedEmail,
        password: password,
      );
      await _setSession(
        accessToken: session.accessToken,
        user: session.user,
      );
    });
  }

  Future<void> signInWithGoogle() async {
    await _ensureInitialized();
    await _runBusy(() async {
      try {
        final account = await _authenticateGoogleWithRetry();
        final idToken = account.authentication.idToken?.trim();
        if (idToken == null || idToken.isEmpty) {
          throw const AuthException(
            'Google sign-in did not return a valid identity token. Please try again.',
          );
        }

        final session = await _authApiClient.signInWithGoogle(
          idToken: idToken,
          email: account.email,
          displayName: account.displayName ?? account.email,
          photoUrl: account.photoUrl,
        );
        await _setSession(
          accessToken: session.accessToken,
          user: session.user,
        );
      } on GoogleSignInException catch (error) {
        throw AuthException(_toUserMessageForGoogleException(error));
      } on PlatformException catch (error) {
        throw AuthException(_toUserMessageForPlatformException(error));
      } on AuthApiException catch (error) {
        throw AuthException(error.message);
      } on AuthException {
        rethrow;
      } catch (error, stackTrace) {
        if (kDebugMode) {
          debugPrint('Google sign-in unexpected error: $error');
          debugPrintStack(stackTrace: stackTrace);
        }
        final detail = _normalizeUnknownError(error);
        if (detail != null) {
          throw AuthException('Google sign-in failed: $detail');
        }
        throw const AuthException('Google sign-in failed. Please try again.');
      }
    });
  }

  Future<void> signOut() async {
    await _ensureInitialized();
    await _runBusy(() async {
      final previousUser = _currentUser;
      await _clearSession(notify: false);

      if (previousUser?.provider == AuthProvider.google) {
        try {
          await _googleSignIn.signOut();
        } catch (_) {}
      }
    });
    notifyListeners();
  }

  Future<void> _ensureInitialized() async {
    if (_initialized) {
      return;
    }
    await initialize();
  }

  Future<void> _hydrateSessionFromDisk() async {
    final raw = _preferences?.getString(_sessionKey);
    if (raw == null || raw.trim().isEmpty) {
      return;
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        await _preferences?.remove(_sessionKey);
        return;
      }

      final accessToken = _readNonEmptyString(decoded['access_token']);
      final user = AuthUser.fromJson(decoded['user']);
      if (accessToken == null || user == null) {
        await _preferences?.remove(_sessionKey);
        return;
      }

      _accessToken = accessToken;
      _currentUser = user;
    } catch (_) {
      await _preferences?.remove(_sessionKey);
    }
  }

  Future<void> _refreshSessionFromBackend() async {
    final token = _accessToken;
    if (token == null || token.trim().isEmpty) {
      return;
    }

    try {
      final user = await _authApiClient.fetchCurrentUser(accessToken: token);
      await _setSession(
        accessToken: token,
        user: user,
        notify: false,
      );
    } on AuthApiException catch (error) {
      if (error.isUnauthorized) {
        await _clearSession(notify: false);
      }
    } catch (_) {}
  }

  Future<void> _initializeGoogleSignIn({bool force = false}) async {
    if (_googleInitialized && !force) {
      return;
    }

    final serverClientId =
        _serverClientId.trim().isEmpty ? null : _serverClientId.trim();
    await _googleSignIn.initialize(serverClientId: serverClientId);
    _googleInitialized = true;
  }

  Future<GoogleSignInAccount> _authenticateGoogleWithRetry() async {
    if (_serverClientId.trim().isEmpty) {
      throw const AuthException(
        'Google sign-in setup is incomplete. Add GOOGLE_SERVER_CLIENT_ID to google_sign_in.env.json.',
      );
    }

    await _initializeGoogleSignIn();
    if (!_googleSignIn.supportsAuthenticate()) {
      throw const AuthException(
        'Google sign-in is not available on this device.',
      );
    }

    try {
      final lightweightAccount = await _attemptGoogleBottomSheetSignIn();
      if (lightweightAccount != null) {
        return lightweightAccount;
      }

      return await _googleSignIn.authenticate();
    } on PlatformException catch (error) {
      if (_isCredentialChannelError(error)) {
        _googleInitialized = false;
        await _initializeGoogleSignIn(force: true);
        final lightweightAccount = await _attemptGoogleBottomSheetSignIn();
        if (lightweightAccount != null) {
          return lightweightAccount;
        }
        return _googleSignIn.authenticate();
      }
      rethrow;
    }
  }

  Future<GoogleSignInAccount?> _attemptGoogleBottomSheetSignIn() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return null;
    }
    final attempt = _googleSignIn.attemptLightweightAuthentication(
      reportAllExceptions: true,
    );
    if (attempt == null) {
      return null;
    }
    return attempt;
  }

  String _toUserMessageForGoogleException(GoogleSignInException error) {
    final detail = _firstNonEmpty(<String?>[
      _cleanErrorText(error.description),
      _cleanErrorText(error.details?.toString()),
    ]);

    return switch (error.code) {
      GoogleSignInExceptionCode.canceled => 'Google sign-in was canceled.',
      GoogleSignInExceptionCode.interrupted =>
        'Google sign-in was interrupted. Please try again.',
      GoogleSignInExceptionCode.uiUnavailable =>
        'Google sign-in is unavailable right now on this device.',
      GoogleSignInExceptionCode.clientConfigurationError =>
        'Google sign-in is not configured for this build. Verify OAuth Android client package and SHA fingerprints for com.gico.stepped.',
      GoogleSignInExceptionCode.providerConfigurationError =>
        'Google sign-in is temporarily unavailable on this device. Please use email sign-in for now.',
      GoogleSignInExceptionCode.userMismatch =>
        'Google account mismatch detected. Sign out and try again.',
      GoogleSignInExceptionCode.unknownError => detail == null
          ? 'Google sign-in failed.'
          : 'Google sign-in failed: $detail',
    };
  }

  String _toUserMessageForPlatformException(PlatformException error) {
    final code = error.code.toLowerCase();
    final message = _cleanErrorText(error.message);

    if (_isCredentialChannelError(error)) {
      return 'Google sign-in could not start. Fully close and reopen the app, then try again.';
    }
    if (code.contains('network') ||
        (message != null && message.toLowerCase().contains('network'))) {
      return 'Network issue while contacting Google. Check your connection and try again.';
    }
    if (code.contains('sign_in_failed') ||
        (message != null &&
            (message.contains('ApiException: 10') ||
                message.toLowerCase().contains('developer error')))) {
      return 'Google sign-in is misconfigured for this build. Ensure OAuth Android client uses package com.gico.stepped with correct SHA-1 and SHA-256.';
    }
    if (code.contains('canceled') ||
        (message != null &&
            (message.contains('12501') ||
                message.toLowerCase().contains('cancel')))) {
      return 'Google sign-in was canceled.';
    }
    if (message != null) {
      return 'Google sign-in failed: $message';
    }
    return 'Google sign-in failed.';
  }

  bool _isCredentialChannelError(PlatformException error) {
    final code = error.code.toLowerCase();
    final message = (error.message ?? '').toLowerCase();
    return code.contains('channel-error') &&
        (message.contains(
                'google_sign_in_android.googlesigninapi.getcredential') ||
            message.contains('unable to establish connection on channel'));
  }

  Future<void> _setSession({
    required String accessToken,
    required AuthUser user,
    bool notify = true,
  }) async {
    _accessToken = accessToken;
    _currentUser = user;
    final serialized = jsonEncode(
      <String, dynamic>{
        'access_token': accessToken,
        'user': user.toJson(),
      },
    );
    await _preferences?.setString(_sessionKey, serialized);
    if (notify) {
      notifyListeners();
    }
  }

  Future<void> _clearSession({bool notify = true}) async {
    _accessToken = null;
    _currentUser = null;
    await _preferences?.remove(_sessionKey);
    if (notify) {
      notifyListeners();
    }
  }

  Future<void> _runBusy(Future<void> Function() action) async {
    _setBusy(true);
    try {
      await action();
    } on AuthApiException catch (error) {
      throw AuthException(error.message);
    } finally {
      _setBusy(false);
    }
  }

  void _setBusy(bool value, {bool notify = true}) {
    if (_isBusy == value) {
      return;
    }
    _isBusy = value;
    if (notify) {
      notifyListeners();
    }
  }

  static String _normalizeEmail(String raw) => raw.trim().toLowerCase();

  static bool _isValidEmail(String email) {
    const pattern = r'^[^\s@]+@[^\s@]+\.[^\s@]+$';
    return RegExp(pattern).hasMatch(email);
  }

  static String? _readNonEmptyString(dynamic value) {
    if (value is! String) {
      return null;
    }
    final normalized = value.trim();
    return normalized.isEmpty ? null : normalized;
  }

  static String? _normalizeUnknownError(Object error) {
    final text = _cleanErrorText(error.toString());
    if (text == null) {
      return null;
    }
    if (text == 'null') {
      return null;
    }
    return text;
  }

  static String? _cleanErrorText(String? value) {
    if (value == null) {
      return null;
    }
    var normalized = value.trim();
    if (normalized.isEmpty) {
      return null;
    }
    if (normalized.startsWith('Exception: ')) {
      normalized = normalized.substring('Exception: '.length).trim();
    }
    if (normalized.startsWith('AuthException: ')) {
      normalized = normalized.substring('AuthException: '.length).trim();
    }
    return normalized.isEmpty ? null : normalized;
  }

  static String? _firstNonEmpty(List<String?> values) {
    for (final value in values) {
      final cleaned = _cleanErrorText(value);
      if (cleaned != null) {
        return cleaned;
      }
    }
    return null;
  }
}

class AuthException implements Exception {
  const AuthException(this.message);

  final String message;

  @override
  String toString() => message;
}
