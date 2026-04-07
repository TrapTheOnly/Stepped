import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
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
    firebase_auth.FirebaseAuth? firebaseAuth,
    GoogleSignIn? googleSignIn,
    AuthApiClient? authApiClient,
  })  : _firebaseAuth = firebaseAuth ?? firebase_auth.FirebaseAuth.instance,
        _googleSignIn = googleSignIn ?? GoogleSignIn.instance,
        _authApiClient = authApiClient ?? AuthApiClient();

  final firebase_auth.FirebaseAuth _firebaseAuth;
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
  bool get hasPasswordProvider => _firebaseAuth.currentUser?.providerData.any(
            (entry) => entry.providerId == 'password',
          ) ??
          (_currentUser?.provider == AuthProvider.password);
  bool get hasGoogleProvider => _firebaseAuth.currentUser?.providerData.any(
            (entry) => entry.providerId == 'google.com',
          ) ??
          (_currentUser?.provider == AuthProvider.google);

  Future<String?> getFreshAccessToken({bool forceRefresh = false}) async {
    await _ensureInitialized();
    final firebaseUser = _firebaseAuth.currentUser;
    if (firebaseUser == null) {
      return _accessToken;
    }

    var refreshed = await firebaseUser.getIdToken(forceRefresh);
    if (!forceRefresh && (refreshed == null || refreshed.trim().isEmpty)) {
      refreshed = await firebaseUser.getIdToken(true);
    }
    final normalized = refreshed?.trim();
    if (normalized == null || normalized.isEmpty) {
      await _clearSession();
      return null;
    }
    if (normalized != _accessToken) {
      await _setSession(
        accessToken: normalized,
        user: _currentUser ?? _mapFirebaseUser(firebaseUser),
      );
    }
    return normalized;
  }

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    _setBusy(true, notify: false);
    try {
      _preferences = await SharedPreferences.getInstance();
      await _hydrateSessionFromDisk();
      await _refreshSessionFromFirebase();
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

    if (normalizedName.length < 4) {
      throw const AuthException(
        'Use at least 4 characters for your display name.',
      );
    }
    if (!_isValidEmail(normalizedEmail)) {
      throw const AuthException('Enter a valid email address.');
    }
    if (password.length < 10) {
      throw const AuthException('Password should be at least 10 characters.');
    }

    try {
      await _runBusy(() async {
        final credentials = await _firebaseAuth.createUserWithEmailAndPassword(
          email: normalizedEmail,
          password: password,
        );
        final user = credentials.user;
        if (user == null) {
          throw const AuthException(
              'Account was created, but no user session was returned.');
        }

        if ((user.displayName ?? '').trim() != normalizedName) {
          await user.updateDisplayName(normalizedName);
        }

        await _syncSessionFromFirebaseUser(
          user,
          forceRefreshToken: true,
        );
      });
    } on firebase_auth.FirebaseAuthException catch (error) {
      throw AuthException(_toUserMessageForEmailRegistrationException(error));
    }
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

    try {
      await _runBusy(() async {
        final credentials = await _firebaseAuth.signInWithEmailAndPassword(
          email: normalizedEmail,
          password: password,
        );
        final user = credentials.user;
        if (user == null) {
          throw const AuthException(
              'Sign-in succeeded, but no user session was returned.');
        }

        await _syncSessionFromFirebaseUser(
          user,
          forceRefreshToken: true,
        );
      });
    } on firebase_auth.FirebaseAuthException catch (error) {
      throw AuthException(_toUserMessageForEmailSignInException(error));
    }
  }

  Future<void> signInWithGoogle() async {
    await _ensureInitialized();
    await _runBusy(() async {
      try {
        final account = await _authenticateGoogleWithRetry();
        final auth = account.authentication;
        final idToken = auth.idToken?.trim();
        if (idToken == null || idToken.isEmpty) {
          throw const AuthException(
            'Google sign-in did not return a valid identity token. Check Firebase Android app setup and try again.',
          );
        }

        final credential = firebase_auth.GoogleAuthProvider.credential(
          idToken: idToken,
        );

        final userCredential =
            await _firebaseAuth.signInWithCredential(credential);
        final user = userCredential.user;
        if (user == null) {
          throw const AuthException(
              'Google sign-in succeeded, but no Firebase user was returned.');
        }

        await _syncSessionFromFirebaseUser(
          user,
          forceRefreshToken: true,
        );
      } on GoogleSignInException catch (error) {
        throw AuthException(_toUserMessageForGoogleException(error));
      } on PlatformException catch (error) {
        throw AuthException(_toUserMessageForPlatformException(error));
      } on firebase_auth.FirebaseAuthException catch (error) {
        throw AuthException(_toUserMessageForFirebaseAuthException(error));
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
      await _clearSession(notify: false);

      try {
        await _googleSignIn.signOut();
      } catch (_) {}

      await _firebaseAuth.signOut();
    });
    notifyListeners();
  }

  Future<void> updateAccountProfile({
    required String displayName,
    String? photoUrl,
  }) async {
    await _ensureInitialized();
    final firebaseUser = _firebaseAuth.currentUser;
    if (firebaseUser == null) {
      throw const AuthException('You need to sign in again to edit profile.');
    }

    final normalizedName = displayName.trim();
    if (normalizedName.length < 2) {
      throw const AuthException(
        'Use at least 2 characters for your display name.',
      );
    }

    final normalizedPhotoUrl = photoUrl?.trim();
    try {
      await _runBusy(() async {
        final currentName = firebaseUser.displayName?.trim() ?? '';
        if (currentName != normalizedName) {
          await firebaseUser.updateDisplayName(normalizedName);
        }

        if (normalizedPhotoUrl != null) {
          final currentPhotoUrl = firebaseUser.photoURL?.trim();
          final nextPhotoUrl =
              normalizedPhotoUrl.isEmpty ? null : normalizedPhotoUrl;
          if (currentPhotoUrl != nextPhotoUrl) {
            await firebaseUser.updatePhotoURL(nextPhotoUrl);
          }
        }

        await _syncSessionFromFirebaseUser(
          firebaseUser,
          forceRefreshToken: true,
        );
      });
    } on firebase_auth.FirebaseAuthException catch (error) {
      throw AuthException(_toUserMessageForFirebaseAuthException(error));
    }
  }

  Future<void> setOrChangePassword({
    String? currentPassword,
    required String newPassword,
  }) async {
    await _ensureInitialized();
    final firebaseUser = _firebaseAuth.currentUser;
    if (firebaseUser == null) {
      throw const AuthException('You need to sign in again to change password.');
    }

    final normalizedNewPassword = newPassword.trim();
    if (normalizedNewPassword.length < 10) {
      throw const AuthException('Password should be at least 10 characters.');
    }

    final email = firebaseUser.email?.trim();
    if (email == null || email.isEmpty) {
      throw const AuthException(
        'This account does not have an email address available.',
      );
    }

    try {
      await _runBusy(() async {
        if (hasPasswordProvider) {
          final normalizedCurrentPassword = currentPassword?.trim();
          if (normalizedCurrentPassword != null &&
              normalizedCurrentPassword.isNotEmpty) {
            final credential = firebase_auth.EmailAuthProvider.credential(
              email: email,
              password: normalizedCurrentPassword,
            );
            await firebaseUser.reauthenticateWithCredential(credential);
          }
          await firebaseUser.updatePassword(normalizedNewPassword);
        } else {
          final credential = firebase_auth.EmailAuthProvider.credential(
            email: email,
            password: normalizedNewPassword,
          );
          await firebaseUser.linkWithCredential(credential);
        }

        await _syncSessionFromFirebaseUser(
          firebaseUser,
          forceRefreshToken: true,
        );
      });
    } on firebase_auth.FirebaseAuthException catch (error) {
      if (error.code == 'requires-recent-login') {
        if (hasPasswordProvider) {
          throw const AuthException(
            'Enter your current password to change it.',
          );
        }
        throw const AuthException(
          'Sign in again before setting a password for this account.',
        );
      }
      throw AuthException(_toUserMessageForFirebaseAuthException(error));
    }
  }

  Future<void> replaceLocalProfile({
    String? displayName,
    String? photoUrl,
    bool overwritePhotoUrl = false,
  }) async {
    await _ensureInitialized();
    final current = _currentUser;
    if (current == null || _accessToken == null) {
      return;
    }

    final normalizedPhotoUrl = photoUrl?.trim();
    final nextUser = current.copyWith(
      displayName: displayName?.trim().isNotEmpty == true
          ? displayName!.trim()
          : current.displayName,
      photoUrl: overwritePhotoUrl
          ? ((normalizedPhotoUrl != null && normalizedPhotoUrl.isNotEmpty)
              ? normalizedPhotoUrl
              : null)
          : (normalizedPhotoUrl != null && normalizedPhotoUrl.isNotEmpty
              ? normalizedPhotoUrl
              : current.photoUrl),
    );
    await _setSession(
      accessToken: _accessToken!,
      user: nextUser,
    );
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

  Future<void> _refreshSessionFromFirebase() async {
    final firebaseUser = _firebaseAuth.currentUser;
    if (firebaseUser == null) {
      await _clearSession(notify: false);
      return;
    }

    try {
      await _syncSessionFromFirebaseUser(
        firebaseUser,
        notify: false,
      );
    } on AuthApiException catch (error) {
      if (error.isUnauthorized) {
        try {
          await _syncSessionFromFirebaseUser(
            firebaseUser,
            forceRefreshToken: true,
            notify: false,
          );
          return;
        } on AuthApiException catch (retryError) {
          if (retryError.isUnauthorized) {
            await _firebaseAuth.signOut();
            await _clearSession(notify: false);
          }
        }
      }
    } catch (_) {}
  }

  Future<void> _syncSessionFromFirebaseUser(
    firebase_auth.User firebaseUser, {
    bool forceRefreshToken = false,
    bool notify = true,
  }) async {
    final accessToken = await firebaseUser.getIdToken(forceRefreshToken);
    final normalizedToken = accessToken?.trim();
    if (normalizedToken == null || normalizedToken.isEmpty) {
      throw const AuthException('Could not obtain a Firebase session token.');
    }

    AuthUser user;
    try {
      user = await _authApiClient.fetchCurrentUser(
        accessToken: normalizedToken,
      );
    } on AuthApiException catch (_) {
      user = _mapFirebaseUser(firebaseUser);
    }

    await _setSession(
      accessToken: normalizedToken,
      user: user,
      notify: notify,
    );
  }

  AuthUser _mapFirebaseUser(firebase_auth.User firebaseUser) {
    final providerId = firebaseUser.providerData.any(
      (entry) => entry.providerId == 'google.com',
    )
        ? AuthProvider.google
        : AuthProvider.password;

    final email = firebaseUser.email?.trim();
    final displayName = _firstNonEmpty(<String?>[
      _cleanErrorText(firebaseUser.displayName),
      email?.split('@').first,
      'Traveler',
    ])!;

    return AuthUser(
      id: firebaseUser.uid,
      email: email ?? '',
      displayName: displayName,
      provider: providerId,
      photoUrl: _cleanErrorText(firebaseUser.photoURL),
    );
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
    await _initializeGoogleSignIn();
    if (!_googleSignIn.supportsAuthenticate()) {
      throw const AuthException(
        'Google sign-in is not available on this device.',
      );
    }

    try {
      await _resetGoogleAuthenticationState();
      return await _googleSignIn.authenticate();
    } on PlatformException catch (error) {
      if (_isCredentialChannelError(error)) {
        _googleInitialized = false;
        await _initializeGoogleSignIn(force: true);
        return _googleSignIn.authenticate();
      }
      rethrow;
    }
  }

  Future<void> _resetGoogleAuthenticationState() async {
    try {
      await _googleSignIn.disconnect();
      return;
    } catch (_) {}

    try {
      await _googleSignIn.signOut();
    } catch (_) {}
  }

  String _toUserMessageForGoogleException(GoogleSignInException error) {
    final detail = _firstNonEmpty(<String?>[
      _cleanErrorText(error.description),
      _cleanErrorText(error.details?.toString()),
    ]);

    return switch (error.code) {
      GoogleSignInExceptionCode.canceled =>
        '',
      GoogleSignInExceptionCode.interrupted =>
        'Google sign-in was interrupted. Please try again.',
      GoogleSignInExceptionCode.uiUnavailable =>
        'Google sign-in is unavailable right now on this device.',
      GoogleSignInExceptionCode.clientConfigurationError =>
        'Google sign-in is not configured for this build. Verify the Firebase Android app for package com.gico.stepped and its SHA fingerprints.',
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
      return 'Google sign-in is misconfigured for this build. Ensure Firebase Android app com.gico.stepped has the correct SHA-1 and SHA-256.';
    }
    if (code.contains('canceled') ||
        (message != null &&
            (message.contains('12501') ||
                message.toLowerCase().contains('cancel')))) {
      return '';
    }
    if (message != null) {
      return 'Google sign-in failed: $message';
    }
    return 'Google sign-in failed.';
  }

  String _toUserMessageForFirebaseAuthException(
    firebase_auth.FirebaseAuthException error,
  ) {
    return switch (error.code) {
      'account-exists-with-different-credential' =>
        'This email is already linked to a different sign-in method.',
      'invalid-credential' =>
        'Those sign-in details were not accepted. Please try again.',
      'operation-not-allowed' =>
        'Google auth is not enabled in Firebase Authentication. Enable Google in Firebase Console > Authentication > Sign-in method.',
      'user-disabled' => 'This account has been disabled.',
      'network-request-failed' =>
        'Network issue while contacting Firebase. Check your connection and try again.',
      'email-already-in-use' =>
        'This email is already registered. Try signing in instead.',
      'invalid-email' => 'Enter a valid email address.',
      'invalid-login-credentials' =>
        'Incorrect email or password. If this account was created with Google, use Continue with Google instead.',
      'wrong-password' => 'Incorrect email or password.',
      'user-not-found' => 'Incorrect email or password.',
      'too-many-requests' =>
        'Too many sign-in attempts right now. Please wait a moment and try again.',
      'weak-password' => 'Password should be at least 10 characters.',
      _ => error.message?.trim().isNotEmpty == true
          ? error.message!.trim()
          : 'Authentication failed.',
    };
  }

  String _toUserMessageForEmailSignInException(
    firebase_auth.FirebaseAuthException error,
  ) {
    return switch (error.code) {
      'invalid-credential' || 'invalid-login-credentials' || 'wrong-password' || 'user-not-found' =>
        'Incorrect email or password. If this account was created with Google, use Continue with Google instead.',
      'invalid-email' => 'Enter a valid email address.',
      'user-disabled' => 'This account has been disabled.',
      'network-request-failed' =>
        'We could not reach the sign-in service. Check your connection and try again.',
      'too-many-requests' =>
        'Too many sign-in attempts right now. Please wait a moment and try again.',
      _ => 'We could not sign you in with that email and password.',
    };
  }

  String _toUserMessageForEmailRegistrationException(
    firebase_auth.FirebaseAuthException error,
  ) {
    return switch (error.code) {
      'email-already-in-use' =>
        'That email already has an account. Try signing in instead.',
      'invalid-email' => 'Enter a valid email address.',
      'weak-password' => 'Password should be at least 10 characters.',
      'network-request-failed' =>
        'We could not reach the sign-up service. Check your connection and try again.',
      'too-many-requests' =>
        'Too many sign-up attempts right now. Please wait a moment and try again.',
      _ => 'We could not create your account right now. Please try again.',
    };
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
