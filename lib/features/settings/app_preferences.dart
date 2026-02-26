import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _themeModeKey = 'stepped_theme_mode';
const _displayNameKey = 'stepped_display_name';
const _homeBaseKey = 'stepped_home_base';
const _confirmWishlistDeleteKey = 'stepped_confirm_wishlist_delete';
const _showWishlistDatesKey = 'stepped_show_wishlist_dates';
const _geminiApiKeyKey = 'stepped_gemini_api_key';

class AppPreferences {
  const AppPreferences({
    required this.themeMode,
    required this.displayName,
    required this.homeBase,
    required this.confirmWishlistDelete,
    required this.showWishlistDates,
    required this.geminiApiKey,
  });

  static const defaults = AppPreferences(
    themeMode: ThemeMode.system,
    displayName: 'Traveler',
    homeBase: '',
    confirmWishlistDelete: true,
    showWishlistDates: true,
    geminiApiKey: '',
  );

  final ThemeMode themeMode;
  final String displayName;
  final String homeBase;
  final bool confirmWishlistDelete;
  final bool showWishlistDates;
  final String geminiApiKey;

  AppPreferences copyWith({
    ThemeMode? themeMode,
    String? displayName,
    String? homeBase,
    bool? confirmWishlistDelete,
    bool? showWishlistDates,
    String? geminiApiKey,
  }) {
    return AppPreferences(
      themeMode: themeMode ?? this.themeMode,
      displayName: displayName ?? this.displayName,
      homeBase: homeBase ?? this.homeBase,
      confirmWishlistDelete:
          confirmWishlistDelete ?? this.confirmWishlistDelete,
      showWishlistDates: showWishlistDates ?? this.showWishlistDates,
      geminiApiKey: geminiApiKey ?? this.geminiApiKey,
    );
  }
}

final appPreferencesProvider =
    AsyncNotifierProvider<AppPreferencesController, AppPreferences>(
  AppPreferencesController.new,
);

class AppPreferencesController extends AsyncNotifier<AppPreferences> {
  SharedPreferences? _preferences;

  @override
  Future<AppPreferences> build() async {
    _preferences = await SharedPreferences.getInstance();
    return _readFromPreferences();
  }

  Future<void> updateThemeMode(ThemeMode themeMode) async {
    final prefs = await _ensurePreferences();
    await prefs.setString(_themeModeKey, _encodeThemeMode(themeMode));
    _emitUpdated((current) => current.copyWith(themeMode: themeMode));
  }

  Future<void> updateDisplayName(String displayName) async {
    final normalized = displayName.trim();
    final fallback = AppPreferences.defaults.displayName;
    final nextValue = normalized.isEmpty ? fallback : normalized;
    final prefs = await _ensurePreferences();
    await prefs.setString(_displayNameKey, nextValue);
    _emitUpdated((current) => current.copyWith(displayName: nextValue));
  }

  Future<void> updateHomeBase(String homeBase) async {
    final normalized = homeBase.trim();
    final prefs = await _ensurePreferences();
    if (normalized.isEmpty) {
      await prefs.remove(_homeBaseKey);
    } else {
      await prefs.setString(_homeBaseKey, normalized);
    }
    _emitUpdated((current) => current.copyWith(homeBase: normalized));
  }

  Future<void> updateConfirmWishlistDelete(bool value) async {
    final prefs = await _ensurePreferences();
    await prefs.setBool(_confirmWishlistDeleteKey, value);
    _emitUpdated((current) => current.copyWith(confirmWishlistDelete: value));
  }

  Future<void> updateShowWishlistDates(bool value) async {
    final prefs = await _ensurePreferences();
    await prefs.setBool(_showWishlistDatesKey, value);
    _emitUpdated((current) => current.copyWith(showWishlistDates: value));
  }

  Future<void> updateGeminiApiKey(String value) async {
    final normalized = value.trim();
    final prefs = await _ensurePreferences();
    if (normalized.isEmpty) {
      await prefs.remove(_geminiApiKeyKey);
    } else {
      await prefs.setString(_geminiApiKeyKey, normalized);
    }
    _emitUpdated((current) => current.copyWith(geminiApiKey: normalized));
  }

  Future<void> resetToDefaults() async {
    final prefs = await _ensurePreferences();
    await prefs.setString(
      _themeModeKey,
      _encodeThemeMode(AppPreferences.defaults.themeMode),
    );
    await prefs.setString(_displayNameKey, AppPreferences.defaults.displayName);
    await prefs.remove(_homeBaseKey);
    await prefs.setBool(
      _confirmWishlistDeleteKey,
      AppPreferences.defaults.confirmWishlistDelete,
    );
    await prefs.setBool(
      _showWishlistDatesKey,
      AppPreferences.defaults.showWishlistDates,
    );
    await prefs.remove(_geminiApiKeyKey);
    state = const AsyncData(AppPreferences.defaults);
  }

  Future<SharedPreferences> _ensurePreferences() async {
    final existing = _preferences;
    if (existing != null) {
      return existing;
    }

    final created = await SharedPreferences.getInstance();
    _preferences = created;
    return created;
  }

  AppPreferences _readFromPreferences() {
    final prefs = _preferences;
    if (prefs == null) {
      return AppPreferences.defaults;
    }

    return AppPreferences(
      themeMode: _decodeThemeMode(
            prefs.getString(_themeModeKey),
          ) ??
          AppPreferences.defaults.themeMode,
      displayName: prefs.getString(_displayNameKey) ??
          AppPreferences.defaults.displayName,
      homeBase: prefs.getString(_homeBaseKey) ?? '',
      confirmWishlistDelete: prefs.getBool(_confirmWishlistDeleteKey) ??
          AppPreferences.defaults.confirmWishlistDelete,
      showWishlistDates: prefs.getBool(_showWishlistDatesKey) ??
          AppPreferences.defaults.showWishlistDates,
      geminiApiKey: prefs.getString(_geminiApiKeyKey) ?? '',
    );
  }

  void _emitUpdated(AppPreferences Function(AppPreferences current) update) {
    final current = state.valueOrNull ?? _readFromPreferences();
    state = AsyncData(update(current));
  }

  static ThemeMode? _decodeThemeMode(String? raw) {
    return switch (raw) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      'system' => ThemeMode.system,
      _ => null,
    };
  }

  static String _encodeThemeMode(ThemeMode mode) {
    return switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    };
  }
}
