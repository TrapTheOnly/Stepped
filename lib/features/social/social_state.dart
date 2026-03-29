import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/db/app_db.dart';
import '../../data/repositories/trips_repository.dart';
import '../../data/repositories/visits_repository.dart';
import '../auth/auth_controller.dart';
import '../auth/auth_user.dart';
import '../settings/app_preferences.dart';
import '../trips/trip_city_models.dart';
import 'social_api_client.dart';
import 'social_models.dart';

final socialApiClientProvider = Provider<SocialApiClient>((ref) {
  return SocialApiClient();
});

class SocialSession {
  const SocialSession({
    required this.accessToken,
    required this.user,
  });

  final String accessToken;
  final AuthUser user;
}

final socialSessionProvider = Provider<SocialSession?>((ref) {
  final authController = ref.watch(authControllerProvider);
  final accessToken = authController.accessToken?.trim();
  final user = authController.currentUser;
  if (user == null || accessToken == null || accessToken.isEmpty) {
    return null;
  }
  return SocialSession(
    accessToken: accessToken,
    user: user,
  );
});

final socialProfileSnapshotProvider = Provider<SocialProfileSnapshot>((ref) {
  final authController = ref.watch(authControllerProvider);
  final preferences =
      ref.watch(appPreferencesProvider).valueOrNull ?? AppPreferences.defaults;
  final preferredDisplayName = preferences.displayName.trim();
  final fallbackDisplayName = authController.currentUser?.displayName.trim();
  final displayName = preferredDisplayName.isNotEmpty
      ? preferredDisplayName
      : (fallbackDisplayName != null && fallbackDisplayName.isNotEmpty
          ? fallbackDisplayName
          : AppPreferences.defaults.displayName);

  return SocialProfileSnapshot(
    displayName: displayName,
    photoUrl: _nonEmptyOrNull(authController.currentUser?.photoUrl),
    homeBase: preferences.homeBase.trim(),
    bio: preferences.bio.trim(),
  );
});

final socialTravelSnapshotProvider = Provider<SocialTravelSnapshot?>((ref) {
  final profile = ref.watch(socialProfileSnapshotProvider);
  final trips = ref.watch(tripsStreamProvider).valueOrNull;
  final visits = ref.watch(visitedCountriesProvider).valueOrNull;
  if (trips == null || visits == null) {
    return null;
  }

  return SocialTravelSnapshot(
    profile: profile,
    trips: <SocialTripSummary>[
      for (final trip in trips)
        SocialTripSummary(
          id: trip.id?.toString() ?? _fallbackTripId(trip),
          countryCode: trip.countryCode.toUpperCase(),
          countryName: trip.countryName,
          startDate: trip.startDate,
          endDate: trip.endDate,
          cities: trip.cities,
          cityEntries: decodeTripCityEntries(
            cityDataJson: trip.cityDataJson,
            legacyCities: trip.cities,
          ),
          coverImageUrl: _remoteImageOrNull(trip.coverImageUri),
          notes: trip.notes,
        ),
    ],
    visitedCountries: <SocialVisitedCountry>[
      for (final visit in visits)
        SocialVisitedCountry(
          countryCode: visit.countryCode.toUpperCase(),
          countryName: visit.countryName,
          visitedAt: visit.visitedAt,
        ),
    ],
  );
});

String _fallbackTripId(TripRecord trip) {
  return '${trip.countryCode}-${trip.startDate}-${trip.endDate}';
}

String? _nonEmptyOrNull(String? value) {
  final normalized = value?.trim();
  if (normalized == null || normalized.isEmpty) {
    return null;
  }
  return normalized;
}

String? _remoteImageOrNull(String? value) {
  final normalized = _nonEmptyOrNull(value);
  if (normalized == null) {
    return null;
  }
  final uri = Uri.tryParse(normalized);
  if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
    return null;
  }
  if (uri.scheme != 'http' && uri.scheme != 'https') {
    return null;
  }
  return normalized;
}

class FriendsHubData {
  const FriendsHubData({
    required this.me,
    required this.friends,
  });

  final SocialMeData me;
  final List<FriendSummary> friends;
}

const _friendsHubCacheKeyPrefix = 'stepped_friends_hub_cache_v1_';
const _friendsHubCacheMaxAge = Duration(hours: 12);

final socialMeProvider = FutureProvider<SocialMeData>((ref) async {
  final session = ref.watch(socialSessionProvider);
  if (session == null) {
    throw const SocialApiException(
      'You need to sign in to use social features.',
      statusCode: 401,
    );
  }

  return ref.watch(socialApiClientProvider).getCurrentSocialState(
        accessToken: session.accessToken,
      );
});

final socialPrivacyProvider =
    FutureProvider<SocialPrivacySettings>((ref) async {
  final session = ref.watch(socialSessionProvider);
  if (session == null) {
    throw const SocialApiException(
      'You need to sign in to manage wishlist privacy.',
      statusCode: 401,
    );
  }

  final refreshedToken =
      await ref.read(authControllerProvider).getFreshAccessToken();
  return ref.watch(socialApiClientProvider).getMyPrivacy(
        accessToken: refreshedToken ?? session.accessToken,
      );
});

final socialFriendsProvider = FutureProvider<List<FriendSummary>>((ref) async {
  final session = ref.watch(socialSessionProvider);
  if (session == null) {
    throw const SocialApiException(
      'You need to sign in to use social features.',
      statusCode: 401,
    );
  }

  return ref.watch(socialApiClientProvider).getFriends(
        accessToken: session.accessToken,
      );
});

final friendsHubProvider =
    AsyncNotifierProvider<FriendsHubController, FriendsHubData>(
  FriendsHubController.new,
);

class FriendsHubController extends AsyncNotifier<FriendsHubData> {
  @override
  Future<FriendsHubData> build() async {
    final session = ref.watch(socialSessionProvider);
    if (session == null) {
      throw const SocialApiException(
        'You need to sign in to use social features.',
        statusCode: 401,
      );
    }

    final cached = await _FriendsHubCacheStore.read(session.user.id);
    if (cached != null) {
      unawaited(refresh());
      return cached;
    }

    return _fetchAndCache(session);
  }

  Future<void> refresh() async {
    final session = ref.read(socialSessionProvider);
    if (session == null) {
      state = AsyncError(
        const SocialApiException(
          'You need to sign in to use social features.',
          statusCode: 401,
        ),
        StackTrace.current,
      );
      return;
    }

    final cached = state.valueOrNull ?? await _FriendsHubCacheStore.read(session.user.id);
    if (cached != null && state.valueOrNull == null) {
      state = AsyncData(cached);
    }

    try {
      final fresh = await _fetchFresh(session);
      state = AsyncData(fresh);
      unawaited(_FriendsHubCacheStore.write(session.user.id, fresh));
    } catch (error, stackTrace) {
      if (cached == null) {
        state = AsyncError(error, stackTrace);
        return;
      }
      debugPrint('Friends hub refresh failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<FriendsHubData> _fetchAndCache(SocialSession session) async {
    final data = await _fetchFresh(session);
    unawaited(_FriendsHubCacheStore.write(session.user.id, data));
    return data;
  }

  Future<FriendsHubData> _fetchFresh(SocialSession session) async {
    final client = ref.read(socialApiClientProvider);
    final results = await Future.wait<Object>(<Future<Object>>[
      client.getCurrentSocialState(accessToken: session.accessToken),
      client.getFriends(accessToken: session.accessToken),
    ]);
    final me = results[0] as SocialMeData;
    final friends = results[1] as List<FriendSummary>;
    return FriendsHubData(me: me, friends: friends);
  }
}

final friendInvitePreviewProvider =
    FutureProvider.family<FriendInvitePreview, String>((ref, token) async {
  final session = ref.watch(socialSessionProvider);
  if (session == null) {
    throw const SocialApiException(
      'You need to sign in to open this invite.',
      statusCode: 401,
    );
  }

  return ref.watch(socialApiClientProvider).getFriendLinkPreview(
        accessToken: session.accessToken,
        token: token,
      );
});

final friendProfileProvider =
    FutureProvider.family<FriendProfileResponse, String>(
        (ref, friendUserId) async {
  final session = ref.watch(socialSessionProvider);
  if (session == null) {
    throw const SocialApiException(
      'You need to sign in to view friend profiles.',
      statusCode: 401,
    );
  }

  return ref.watch(socialApiClientProvider).getFriendProfile(
        accessToken: session.accessToken,
        friendUserId: friendUserId,
      );
});

final socialSyncBootstrapProvider = Provider<void>((ref) {
  final coordinator = _SocialSyncCoordinator(ref);
  ref.onDispose(coordinator.dispose);

  ref.listen<AuthController>(authControllerProvider, (_, __) {
    coordinator.scheduleProfileSync();
    coordinator.scheduleTravelSync();
  });
  ref.listen<AsyncValue<AppPreferences>>(appPreferencesProvider, (_, __) {
    coordinator.scheduleProfileSync();
    coordinator.scheduleTravelSync();
  });
  ref.listen<AsyncValue<List<TripRecord>>>(tripsStreamProvider, (_, __) {
    coordinator.scheduleTravelSync();
  });
  ref.listen<AsyncValue<List<CountryVisitRecord>>>(visitedCountriesProvider,
      (_, __) {
    coordinator.scheduleTravelSync();
  });

  coordinator.scheduleProfileSync();
  coordinator.scheduleTravelSync();
});

class _SocialSyncCoordinator {
  _SocialSyncCoordinator(this.ref);

  final Ref ref;
  Timer? _profileTimer;
  Timer? _travelTimer;
  String? _lastProfileSignature;
  String? _lastTravelSignature;
  String? _hydratedUserId;
  bool _didHydrateRemoteProfile = false;

  void scheduleProfileSync() {
    _profileTimer?.cancel();
    _profileTimer = Timer(
      const Duration(milliseconds: 850),
      () => unawaited(_syncProfile()),
    );
  }

  void scheduleTravelSync() {
    _travelTimer?.cancel();
    _travelTimer = Timer(
      const Duration(milliseconds: 1100),
      () => unawaited(_syncTravel()),
    );
  }

  Future<void> _syncProfile() async {
    final session = ref.read(socialSessionProvider);
    if (session == null) {
      _hydratedUserId = null;
      _didHydrateRemoteProfile = false;
      _lastProfileSignature = null;
      return;
    }

    if (_hydratedUserId != session.user.id) {
      _hydratedUserId = session.user.id;
      _didHydrateRemoteProfile = false;
      _lastProfileSignature = null;
    }

    await _hydrateRemoteProfileIfNeeded(session);

    final snapshot = ref.read(socialProfileSnapshotProvider);
    final signature = jsonEncode(snapshot.toJson());
    if (signature == _lastProfileSignature) {
      return;
    }

    try {
      await ref.read(socialApiClientProvider).syncProfile(
            accessToken: session.accessToken,
            profile: snapshot,
          );
      _lastProfileSignature = signature;
      ref.invalidate(socialMeProvider);
      ref.invalidate(friendsHubProvider);
    } catch (error, stackTrace) {
      debugPrint('Social profile sync failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> _hydrateRemoteProfileIfNeeded(SocialSession session) async {
    if (_didHydrateRemoteProfile) {
      return;
    }

    _didHydrateRemoteProfile = true;
    try {
      final refreshedToken =
          await ref.read(authControllerProvider).getFreshAccessToken();
      final me = await ref.read(socialApiClientProvider).getCurrentSocialState(
            accessToken: refreshedToken ?? session.accessToken,
          );
      final remoteProfile = me.profile;
      final authController = ref.read(authControllerProvider);
      final currentDisplayName = authController.currentUser?.displayName.trim();
      final remoteDisplayName = remoteProfile.displayName.trim();
      final nextDisplayName = remoteDisplayName.isNotEmpty &&
              (remoteDisplayName != AppPreferences.defaults.displayName ||
                  currentDisplayName == null ||
                  currentDisplayName.isEmpty)
          ? remoteDisplayName
          : (currentDisplayName != null && currentDisplayName.isNotEmpty
              ? currentDisplayName
              : AppPreferences.defaults.displayName);

      await ref.read(appPreferencesProvider.notifier).hydrateProfileCache(
            displayName: nextDisplayName,
            homeBase: remoteProfile.homeBase,
            bio: remoteProfile.bio,
          );

      final remotePhotoUrl = _nonEmptyOrNull(remoteProfile.photoUrl);
      if (remotePhotoUrl != null) {
        await authController.replaceLocalProfile(
          displayName: nextDisplayName,
          photoUrl: remotePhotoUrl,
        );
      } else if (nextDisplayName != (authController.currentUser?.displayName ?? '')) {
        await authController.replaceLocalProfile(displayName: nextDisplayName);
      }

      _lastProfileSignature = jsonEncode(
        SocialProfileSnapshot(
          displayName: nextDisplayName,
          photoUrl: remotePhotoUrl ?? authController.currentUser?.photoUrl,
          homeBase: remoteProfile.homeBase,
          bio: remoteProfile.bio,
        ).toJson(),
      );
      ref.invalidate(socialMeProvider);
      ref.invalidate(friendsHubProvider);
    } catch (error, stackTrace) {
      debugPrint('Remote profile hydration failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> _syncTravel() async {
    final session = ref.read(socialSessionProvider);
    final snapshot = ref.read(socialTravelSnapshotProvider);
    if (session == null || snapshot == null) {
      return;
    }

    final signature = jsonEncode(snapshot.toJson());
    if (signature == _lastTravelSignature) {
      return;
    }

    try {
      await ref.read(socialApiClientProvider).syncTravel(
            accessToken: session.accessToken,
            travel: snapshot,
          );
      _lastTravelSignature = signature;
      ref.invalidate(socialMeProvider);
      ref.invalidate(friendsHubProvider);
    } catch (error, stackTrace) {
      debugPrint('Social travel sync failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  void dispose() {
    _profileTimer?.cancel();
    _travelTimer?.cancel();
  }
}

class _FriendsHubCacheStore {
  const _FriendsHubCacheStore._();

  static String _keyFor(String userId) => '$_friendsHubCacheKeyPrefix$userId';

  static Future<FriendsHubData?> read(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyFor(userId));
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        await prefs.remove(_keyFor(userId));
        return null;
      }
      final map = Map<String, dynamic>.from(decoded);
      final cachedAt = _parseCacheTimestamp(map['cached_at'] ?? map['cachedAt']);
      if (cachedAt != null &&
          DateTime.now().difference(cachedAt) > _friendsHubCacheMaxAge) {
        await prefs.remove(_keyFor(userId));
        return null;
      }
      final meRaw = map['me'];
      final friendsRaw = map['friends'];
      if (meRaw == null || friendsRaw is! List) {
        await prefs.remove(_keyFor(userId));
        return null;
      }
      return FriendsHubData(
        me: SocialMeData.fromJson(meRaw),
        friends: <FriendSummary>[
          for (final entry in friendsRaw) FriendSummary.fromJson(entry),
        ],
      );
    } catch (_) {
      await prefs.remove(_keyFor(userId));
      return null;
    }
  }

  static Future<void> write(String userId, FriendsHubData data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _keyFor(userId),
      jsonEncode(<String, dynamic>{
        'cached_at': DateTime.now().toIso8601String(),
        'me': _socialMeToJson(data.me),
        'friends': <Map<String, dynamic>>[
          for (final friend in data.friends) _friendSummaryToJson(friend),
        ],
      }),
    );
  }

  static DateTime? _parseCacheTimestamp(dynamic raw) {
    if (raw is! String) {
      return null;
    }
    return DateTime.tryParse(raw.trim());
  }

  static Map<String, dynamic> _socialMeToJson(SocialMeData data) {
    return <String, dynamic>{
      'profile': data.profile.toJson(),
      if (data.invite != null) 'active_invite': _socialInviteToJson(data.invite!),
      if (data.stats != null) 'stats': _socialStatsToJson(data.stats!),
      'invites': <Map<String, dynamic>>[
        for (final invite in data.invites) _socialInviteToJson(invite),
      ],
    };
  }

  static Map<String, dynamic> _socialInviteToJson(SocialInviteLink invite) {
    return <String, dynamic>{
      'token': invite.token,
      'url': invite.url,
      'status': invite.status,
      if (invite.createdAt != null)
        'created_at': invite.createdAt!.toIso8601String(),
    };
  }

  static Map<String, dynamic> _socialStatsToJson(SocialStats stats) {
    return <String, dynamic>{
      'total_trips': stats.totalTrips,
      'visited_countries_count': stats.visitedCountriesCount,
      'total_friends': stats.totalFriends,
    };
  }

  static Map<String, dynamic> _friendSummaryToJson(FriendSummary friend) {
    return <String, dynamic>{
      'id': friend.id,
      'display_name': friend.displayName,
      if (friend.photoUrl != null) 'photo_url': friend.photoUrl,
      'home_base': friend.homeBase,
      if (friend.addedAt != null) 'added_at': friend.addedAt!.toIso8601String(),
    };
  }
}
