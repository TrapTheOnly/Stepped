import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../config/runtime_config.dart';

const _themeModeKey = 'stepped_theme_mode';
const _displayNameKey = 'stepped_display_name';
const _homeBaseKey = 'stepped_home_base';
const _bioKey = 'stepped_bio';
const _confirmWishlistDeleteKey = 'stepped_confirm_wishlist_delete';
const _showWishlistDatesKey = 'stepped_show_wishlist_dates';
const _geminiApiKeyKey = 'stepped_gemini_api_key';
const _aiPlannerSourceKey = 'stepped_ai_planner_source';
const _cloudAiBaseUrlKey = 'stepped_cloud_ai_base_url';

enum AiPlannerSource {
  cloud,
  localGemini,
}

class AppPreferences {
  const AppPreferences({
    required this.themeMode,
    required this.displayName,
    required this.homeBase,
    required this.bio,
    required this.confirmWishlistDelete,
    required this.showWishlistDates,
    required this.geminiApiKey,
    required this.aiPlannerSource,
    required this.cloudAiBaseUrl,
  });

  static final defaults = AppPreferences(
    themeMode: ThemeMode.system,
    displayName: 'Traveler',
    homeBase: '',
    bio: '',
    confirmWishlistDelete: true,
    showWishlistDates: true,
    geminiApiKey: '',
    aiPlannerSource: AiPlannerSource.cloud,
    cloudAiBaseUrl: defaultSteppedApiBaseUrl,
  );

  final ThemeMode themeMode;
  final String displayName;
  final String homeBase;
  final String bio;
  final bool confirmWishlistDelete;
  final bool showWishlistDates;
  final String geminiApiKey;
  final AiPlannerSource aiPlannerSource;
  final String cloudAiBaseUrl;

  AppPreferences copyWith({
    ThemeMode? themeMode,
    String? displayName,
    String? homeBase,
    String? bio,
    bool? confirmWishlistDelete,
    bool? showWishlistDates,
    String? geminiApiKey,
    AiPlannerSource? aiPlannerSource,
    String? cloudAiBaseUrl,
  }) {
    return AppPreferences(
      themeMode: themeMode ?? this.themeMode,
      displayName: displayName ?? this.displayName,
      homeBase: homeBase ?? this.homeBase,
      bio: bio ?? this.bio,
      confirmWishlistDelete:
          confirmWishlistDelete ?? this.confirmWishlistDelete,
      showWishlistDates: showWishlistDates ?? this.showWishlistDates,
      geminiApiKey: geminiApiKey ?? this.geminiApiKey,
      aiPlannerSource: aiPlannerSource ?? this.aiPlannerSource,
      cloudAiBaseUrl: cloudAiBaseUrl ?? this.cloudAiBaseUrl,
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
    await _purgeLegacyProfileCache(_preferences!);
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
    _emitUpdated((current) => current.copyWith(displayName: nextValue));
  }

  Future<void> updateHomeBase(String homeBase) async {
    final normalized = homeBase.trim();
    _emitUpdated((current) => current.copyWith(homeBase: normalized));
  }

  Future<void> updateBio(String bio) async {
    final normalized = bio.trim();
    _emitUpdated((current) => current.copyWith(bio: normalized));
  }

  Future<void> hydrateProfileCache({
    required String displayName,
    required String homeBase,
    required String bio,
  }) async {
    final normalizedDisplayName = displayName.trim().isEmpty
        ? AppPreferences.defaults.displayName
        : displayName.trim();
    final normalizedHomeBase = homeBase.trim();
    final normalizedBio = bio.trim();

    _emitUpdated(
      (current) => current.copyWith(
        displayName: normalizedDisplayName,
        homeBase: normalizedHomeBase,
        bio: normalizedBio,
      ),
    );
  }

  Future<void> clearProfileCache() async {
    _emitUpdated(
      (current) => current.copyWith(
        displayName: AppPreferences.defaults.displayName,
        homeBase: '',
        bio: '',
      ),
    );
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

  Future<void> updateAiPlannerSource(AiPlannerSource source) async {
    final prefs = await _ensurePreferences();
    await prefs.setString(_aiPlannerSourceKey, _encodeAiPlannerSource(source));
    _emitUpdated((current) => current.copyWith(aiPlannerSource: source));
  }

  Future<void> updateCloudAiBaseUrl(String value) async {
    final normalized = value.trim();
    final nextValue = normalized.isEmpty
        ? AppPreferences.defaults.cloudAiBaseUrl
        : normalized;
    final prefs = await _ensurePreferences();
    await prefs.setString(_cloudAiBaseUrlKey, nextValue);
    _emitUpdated((current) => current.copyWith(cloudAiBaseUrl: nextValue));
  }

  Future<void> resetToDefaults() async {
    final prefs = await _ensurePreferences();
    await prefs.setString(
      _themeModeKey,
      _encodeThemeMode(AppPreferences.defaults.themeMode),
    );
    await prefs.remove(_displayNameKey);
    await prefs.remove(_homeBaseKey);
    await prefs.remove(_bioKey);
    await prefs.setBool(
      _confirmWishlistDeleteKey,
      AppPreferences.defaults.confirmWishlistDelete,
    );
    await prefs.setBool(
      _showWishlistDatesKey,
      AppPreferences.defaults.showWishlistDates,
    );
    await prefs.remove(_geminiApiKeyKey);
    await prefs.setString(
      _aiPlannerSourceKey,
      _encodeAiPlannerSource(AppPreferences.defaults.aiPlannerSource),
    );
    await prefs.setString(
      _cloudAiBaseUrlKey,
      AppPreferences.defaults.cloudAiBaseUrl,
    );
    state = AsyncData(AppPreferences.defaults);
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
      displayName: AppPreferences.defaults.displayName,
      homeBase: '',
      bio: '',
      confirmWishlistDelete: prefs.getBool(_confirmWishlistDeleteKey) ??
          AppPreferences.defaults.confirmWishlistDelete,
      showWishlistDates: prefs.getBool(_showWishlistDatesKey) ??
          AppPreferences.defaults.showWishlistDates,
      geminiApiKey: prefs.getString(_geminiApiKeyKey) ?? '',
      aiPlannerSource: _decodeAiPlannerSource(
            prefs.getString(_aiPlannerSourceKey),
          ) ??
          AppPreferences.defaults.aiPlannerSource,
      cloudAiBaseUrl: prefs.getString(_cloudAiBaseUrlKey) ??
          AppPreferences.defaults.cloudAiBaseUrl,
    );
  }

  void _emitUpdated(AppPreferences Function(AppPreferences current) update) {
    final current = state.valueOrNull ?? _readFromPreferences();
    state = AsyncData(update(current));
  }

  Future<void> _purgeLegacyProfileCache(SharedPreferences prefs) async {
    await prefs.remove(_displayNameKey);
    await prefs.remove(_homeBaseKey);
    await prefs.remove(_bioKey);
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

  static AiPlannerSource? _decodeAiPlannerSource(String? raw) {
    return switch (raw) {
      'cloud' => AiPlannerSource.cloud,
      'local_gemini' => AiPlannerSource.localGemini,
      _ => null,
    };
  }

  static String _encodeAiPlannerSource(AiPlannerSource source) {
    return switch (source) {
      AiPlannerSource.cloud => 'cloud',
      AiPlannerSource.localGemini => 'local_gemini',
    };
  }
}
