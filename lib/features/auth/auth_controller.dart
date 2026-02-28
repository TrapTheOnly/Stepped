import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'auth_user.dart';

const _sessionKey = 'stepped_auth_session_v1';
const _accountsKey = 'stepped_auth_accounts_v1';

final authControllerProvider = ChangeNotifierProvider<AuthController>((ref) {
  final controller = AuthController();
  unawaited(controller.initialize());
  ref.onDispose(controller.dispose);
  return controller;
});

class AuthController extends ChangeNotifier {
  AuthController({GoogleSignIn? googleSignIn})
      : _googleSignIn = googleSignIn ?? GoogleSignIn.instance;

  final GoogleSignIn _googleSignIn;
  final String _serverClientId =
      const String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID');

  SharedPreferences? _preferences;
  AuthUser? _currentUser;
  bool _initialized = false;
  bool _isBusy = false;
  bool _googleInitialized = false;

  AuthUser? get currentUser => _currentUser;
  bool get isAuthenticated => _currentUser != null;
  bool get isInitialized => _initialized;
  bool get isBusy => _isBusy;

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    _setBusy(true, notify: false);
    try {
      _preferences = await SharedPreferences.getInstance();
      final raw = _preferences?.getString(_sessionKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        _currentUser = AuthUser.fromJson(decoded);
      }
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
      final accounts = await _readAccounts();
      if (accounts.containsKey(normalizedEmail)) {
        throw const AuthException(
          'This email is already registered. Try signing in instead.',
        );
      }

      final salt = _generateSalt();
      accounts[normalizedEmail] = _PasswordAccount(
        email: normalizedEmail,
        displayName: normalizedName,
        passwordHash: _hashPassword(password, salt),
        salt: salt,
      );
      await _writeAccounts(accounts);

      final user = AuthUser(
        id: 'local_${DateTime.now().microsecondsSinceEpoch}',
        email: normalizedEmail,
        displayName: normalizedName,
        provider: AuthProvider.password,
      );
      await _setCurrentUser(user);
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
      final accounts = await _readAccounts();
      final account = accounts[normalizedEmail];
      if (account == null) {
        throw const AuthException(
          'No account found with this email. Create one first.',
        );
      }

      final providedHash = _hashPassword(password, account.salt);
      if (providedHash != account.passwordHash) {
        throw const AuthException('Incorrect password.');
      }

      final user = AuthUser(
        id: 'local_${normalizedEmail.hashCode.abs()}',
        email: account.email,
        displayName: account.displayName,
        provider: AuthProvider.password,
      );
      await _setCurrentUser(user);
    });
  }

  Future<void> signInWithGoogle() async {
    await _ensureInitialized();
    await _runBusy(() async {
      try {
        final account = await _authenticateGoogleWithRetry();
        final user = AuthUser(
          id: account.id,
          email: account.email,
          displayName: account.displayName ?? account.email,
          provider: AuthProvider.google,
          photoUrl: account.photoUrl,
        );
        await _setCurrentUser(user);
      } on GoogleSignInException catch (error) {
        throw AuthException(_toUserMessageForGoogleException(error));
      } on PlatformException catch (error) {
        throw AuthException(_toUserMessageForPlatformException(error));
      } on AuthException {
        rethrow;
      } catch (error) {
        final message = error.toString().toLowerCase();
        if (message.contains('canceled') || message.contains('cancelled')) {
          throw const AuthException('Google sign-in was canceled.');
        }
        throw AuthException(
          'Google sign-in failed. Please try again in a moment.',
        );
      }
    });
  }

  Future<void> signOut() async {
    await _ensureInitialized();
    await _runBusy(() async {
      final user = _currentUser;
      _currentUser = null;
      await _preferences?.remove(_sessionKey);

      if (user?.provider == AuthProvider.google) {
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

  String _toUserMessageForGoogleException(GoogleSignInException error) {
    return switch (error.code) {
      GoogleSignInExceptionCode.canceled => 'Google sign-in was canceled.',
      GoogleSignInExceptionCode.interrupted =>
        'Google sign-in was interrupted. Please try again.',
      GoogleSignInExceptionCode.uiUnavailable =>
        'Google sign-in is unavailable right now on this device.',
      GoogleSignInExceptionCode.clientConfigurationError =>
        'Google sign-in is not available in this app build yet. Please use email sign-in for now.',
      GoogleSignInExceptionCode.providerConfigurationError =>
        'Google sign-in is temporarily unavailable on this device. Please use email sign-in for now.',
      _ => 'Google sign-in failed. Please try again.',
    };
  }

  String _toUserMessageForPlatformException(PlatformException error) {
    if (_isCredentialChannelError(error)) {
      return 'Google sign-in could not start. Fully close and reopen the app, then try again.';
    }
    return 'Google sign-in failed. Please try again.';
  }

  bool _isCredentialChannelError(PlatformException error) {
    final code = error.code.toLowerCase();
    final message = (error.message ?? '').toLowerCase();
    return code.contains('channel-error') &&
        (message.contains(
                'google_sign_in_android.googlesigninapi.getcredential') ||
            message.contains('unable to establish connection on channel'));
  }

  Future<void> _setCurrentUser(AuthUser user) async {
    _currentUser = user;
    final serialized = jsonEncode(user.toJson());
    await _preferences?.setString(_sessionKey, serialized);
    notifyListeners();
  }

  Future<void> _runBusy(Future<void> Function() action) async {
    _setBusy(true);
    try {
      await action();
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

  Future<Map<String, _PasswordAccount>> _readAccounts() async {
    final raw = _preferences?.getString(_accountsKey);
    if (raw == null || raw.trim().isEmpty) {
      return <String, _PasswordAccount>{};
    }

    final decoded = jsonDecode(raw);
    if (decoded is! List<dynamic>) {
      return <String, _PasswordAccount>{};
    }

    final results = <String, _PasswordAccount>{};
    for (final item in decoded) {
      final account = _PasswordAccount.fromJson(item);
      if (account == null) {
        continue;
      }
      results[account.email] = account;
    }
    return results;
  }

  Future<void> _writeAccounts(Map<String, _PasswordAccount> accounts) async {
    final list = accounts.values.map((account) => account.toJson()).toList();
    await _preferences?.setString(_accountsKey, jsonEncode(list));
  }

  static String _normalizeEmail(String raw) => raw.trim().toLowerCase();

  static bool _isValidEmail(String email) {
    const pattern = r'^[^\s@]+@[^\s@]+\.[^\s@]+$';
    return RegExp(pattern).hasMatch(email);
  }

  static String _generateSalt() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    return base64Url.encode(bytes);
  }

  static String _hashPassword(String password, String salt) {
    final input = utf8.encode('$salt::$password');
    return sha256.convert(input).toString();
  }
}

class AuthException implements Exception {
  const AuthException(this.message);

  final String message;

  @override
  String toString() => message;
}

class _PasswordAccount {
  const _PasswordAccount({
    required this.email,
    required this.displayName,
    required this.passwordHash,
    required this.salt,
  });

  final String email;
  final String displayName;
  final String passwordHash;
  final String salt;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'email': email,
      'display_name': displayName,
      'password_hash': passwordHash,
      'salt': salt,
    };
  }

  static _PasswordAccount? fromJson(dynamic raw) {
    if (raw is! Map) {
      return null;
    }

    final email = _readString(raw['email']);
    final displayName = _readString(raw['display_name']);
    final passwordHash = _readString(raw['password_hash']);
    final salt = _readString(raw['salt']);
    if (email == null ||
        displayName == null ||
        passwordHash == null ||
        salt == null) {
      return null;
    }

    return _PasswordAccount(
      email: email.toLowerCase(),
      displayName: displayName,
      passwordHash: passwordHash,
      salt: salt,
    );
  }

  static String? _readString(dynamic value) {
    if (value is! String) {
      return null;
    }
    final normalized = value.trim();
    return normalized.isEmpty ? null : normalized;
  }
}
