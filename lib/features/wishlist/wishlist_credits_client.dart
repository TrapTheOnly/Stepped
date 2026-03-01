import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/runtime_config.dart';
import '../settings/app_preferences.dart';

class WishlistCreditsSnapshot {
  const WishlistCreditsSnapshot({
    required this.plan,
    required this.generationCostCredits,
    required this.monthlyLimit,
    required this.remainingCredits,
    required this.dailyBurstLimit,
    required this.rewardedAdMonthlyLimit,
    required this.rewardedAdRemaining,
    required this.nextResetAt,
  });

  static const fallbackFree = WishlistCreditsSnapshot(
    plan: 'free',
    generationCostCredits: 1,
    monthlyLimit: 10,
    remainingCredits: 10,
    dailyBurstLimit: 2,
    rewardedAdMonthlyLimit: 20,
    rewardedAdRemaining: 20,
    nextResetAt: null,
  );

  final String plan;
  final int generationCostCredits;
  final int monthlyLimit;
  final int remainingCredits;
  final int dailyBurstLimit;
  final int rewardedAdMonthlyLimit;
  final int rewardedAdRemaining;
  final DateTime? nextResetAt;

  int get usedCredits =>
      (monthlyLimit - remainingCredits).clamp(0, monthlyLimit);
  double get usageProgress =>
      monthlyLimit <= 0 ? 0 : (usedCredits / monthlyLimit).clamp(0, 1);

  bool get isPlus => plan.toLowerCase() == 'plus';

  factory WishlistCreditsSnapshot.fromJson(Map<String, dynamic> json) {
    int readInt(String key, int fallback) {
      final raw = json[key];
      if (raw is int) {
        return raw;
      }
      if (raw is num) {
        return raw.round();
      }
      if (raw is String) {
        return int.tryParse(raw.trim()) ?? fallback;
      }
      return fallback;
    }

    DateTime? parseDate(dynamic raw) {
      if (raw is! String || raw.trim().isEmpty) {
        return null;
      }
      return DateTime.tryParse(raw.trim());
    }

    return WishlistCreditsSnapshot(
      plan: (json['plan'] as String?)?.trim().toLowerCase() ?? 'free',
      generationCostCredits: readInt('generation_cost_credits', 1),
      monthlyLimit: readInt('monthly_limit', 10),
      remainingCredits: readInt('remaining_credits', 10),
      dailyBurstLimit: readInt('daily_burst_limit', 2),
      rewardedAdMonthlyLimit: readInt('rewarded_ad_monthly_limit', 20),
      rewardedAdRemaining: readInt('rewarded_ad_remaining', 20),
      nextResetAt: parseDate(json['next_reset_at']),
    );
  }
}

final wishlistCreditsClientProvider = Provider<WishlistCreditsClient>((ref) {
  return const WishlistCreditsClient();
});

final wishlistCreditsProvider =
    FutureProvider<WishlistCreditsSnapshot>((ref) async {
  final prefs =
      ref.watch(appPreferencesProvider).valueOrNull ?? AppPreferences.defaults;
  return ref.watch(wishlistCreditsClientProvider).fetchCredits(prefs: prefs);
});

class WishlistCreditsClient {
  const WishlistCreditsClient();

  Future<WishlistCreditsSnapshot> fetchCredits({
    required AppPreferences prefs,
  }) async {
    if (prefs.aiPlannerSource != AiPlannerSource.cloud ||
        prefs.cloudAiBaseUrl.trim().isEmpty) {
      return WishlistCreditsSnapshot.fallbackFree;
    }

    final uri = _buildCreditsUri(prefs.cloudAiBaseUrl);
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
    try {
      final request = await client.getUrl(uri);
      request.headers.add('X-Stepped-Plan', 'free');
      final response = await request.close();
      final rawBody = await response.transform(utf8.decoder).join();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return WishlistCreditsSnapshot.fallbackFree;
      }
      final decoded = jsonDecode(rawBody);
      if (decoded is! Map<String, dynamic>) {
        return WishlistCreditsSnapshot.fallbackFree;
      }
      return WishlistCreditsSnapshot.fromJson(decoded);
    } catch (_) {
      return WishlistCreditsSnapshot.fallbackFree;
    } finally {
      client.close(force: true);
    }
  }

  Uri _buildCreditsUri(String baseUrl) {
    final parsed = Uri.tryParse(baseUrl.trim());
    if (parsed == null || !parsed.hasScheme || !parsed.hasAuthority) {
      return Uri.parse('$defaultSteppedApiBaseUrl/v1/wishlist/credits');
    }
    final normalizedPath = parsed.path.endsWith('/')
        ? parsed.path.substring(0, parsed.path.length - 1)
        : parsed.path;
    final endpointPath = normalizedPath.isEmpty
        ? '/v1/wishlist/credits'
        : '$normalizedPath/v1/wishlist/credits';
    return parsed.replace(path: endpointPath);
  }
}
