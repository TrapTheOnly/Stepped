import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/widgets.dart';
import 'package:path/path.dart' as path;

import '../../data/db/app_db.dart';
import '../../data/repositories/trips_repository.dart';
import '../../data/repositories/visits_repository.dart';
import '../../data/repositories/wishlist_repository.dart';
import '../auth/auth_controller.dart';
import '../auth/auth_user.dart';
import '../settings/app_preferences.dart';
import '../trips/trip_city_models.dart';
import '../wishlist/widgets/wishlist_editorial_widgets.dart';
import 'social_api_client.dart';
import 'social_asset_urls.dart';
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
  final wishlistItems = ref.watch(wishlistStreamProvider).valueOrNull ??
      const <WishlistItemRecord>[];
  if (trips == null || visits == null) {
    return null;
  }

  final wishlistByLocalId = <int, WishlistItemRecord>{
    for (final item in wishlistItems)
      if (item.id != null) item.id!: item,
  };

  return SocialTravelSnapshot(
    profile: profile,
    trips: <SocialTripSummary>[
      for (final trip in trips)
        SocialTripSummary(
          id: trip.remoteId ?? trip.id?.toString() ?? _fallbackTripId(trip),
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
          sourceWishlistItemId: _resolveTripSourceWishlistRemoteId(
            trip: trip,
            wishlistByLocalId: wishlistByLocalId,
          ),
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

final socialWishlistSnapshotProvider = Provider<SocialWishlistSnapshot?>((ref) {
  final items = ref.watch(wishlistStreamProvider).valueOrNull;
  if (items == null) {
    return null;
  }

  return SocialWishlistSnapshot(
    items: <SocialWishlistItem>[
      for (final item in items)
        SocialWishlistItem(
          id: item.remoteId ??
              item.id?.toString() ??
              _fallbackWishlistItemId(item),
          title: item.title,
          countryCode: _nonEmptyOrNull(item.countryCode),
          countryName: item.countryName ?? '',
          plannedCities: item.plannedCities ?? '',
          plannedStartDate: item.plannedStartDate,
          plannedEndDate: item.plannedEndDate,
          imageUrl: _remoteWishlistImageOrNull(item),
          notes: null,
          aiPlan: _nonEmptyOrNull(item.aiPlan),
          isPinned: item.isPinned,
          createdAt: item.createdAt,
        ),
    ],
  );
});

String _fallbackTripId(TripRecord trip) {
  return '${trip.countryCode}-${trip.startDate}-${trip.endDate}';
}

String _fallbackWishlistItemId(WishlistItemRecord item) {
  final normalizedTitle = item.title
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  if (normalizedTitle.isNotEmpty) {
    return 'wish_$normalizedTitle';
  }
  return 'wish_${item.createdAt}';
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

String? _remoteWishlistImageOrNull(WishlistItemRecord item) {
  final fromPlan = wishlistPrimaryImageUrl(item);
  return _remoteImageOrNull(fromPlan);
}

bool _isBackendManagedSocialImage(String? value) {
  final normalized = normalizeSocialAssetUrl(value);
  if (normalized == null) {
    return false;
  }
  final uri = Uri.tryParse(normalized);
  if (uri == null) {
    return false;
  }
  final scheme = uri.scheme.toLowerCase();
  if (scheme != 'http' && scheme != 'https') {
    return false;
  }
  final host = uri.host.toLowerCase();
  return host == 'firebasestorage.googleapis.com' ||
      host == 'storage.googleapis.com';
}

String _tripRemoteKey(TripRecord trip) {
  return trip.remoteId ?? trip.id?.toString() ?? _fallbackTripId(trip);
}

String _wishlistRemoteKey(WishlistItemRecord item) {
  return item.remoteId ?? item.id?.toString() ?? _fallbackWishlistItemId(item);
}

String? _resolveTripSourceWishlistRemoteId({
  required TripRecord trip,
  required Map<int, WishlistItemRecord> wishlistByLocalId,
}) {
  final localWishlistId = trip.sourceWishlistItemId;
  if (localWishlistId == null) {
    return null;
  }
  final item = wishlistByLocalId[localWishlistId];
  if (item == null) {
    return null;
  }
  return _wishlistRemoteKey(item);
}

String _slugifyCityKey(String value) {
  final normalized = value
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  return normalized.isEmpty ? 'city' : normalized;
}

class _PreparedSocialUploadFile {
  const _PreparedSocialUploadFile({
    required this.filePath,
    required this.deleteAfterUpload,
  });

  final String filePath;
  final bool deleteAfterUpload;

  Future<void> dispose() async {
    if (!deleteAfterUpload) {
      return;
    }
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}
  }
}

Future<_PreparedSocialUploadFile?> _prepareSocialUploadFile(
  String raw, {
  required String tempPrefix,
}) async {
  final normalized = normalizeSocialAssetUrl(raw);
  if (normalized == null || normalized.isEmpty) {
    return null;
  }

  final uri = Uri.tryParse(normalized);
  if (uri != null) {
    final scheme = uri.scheme.toLowerCase();
    if (scheme == 'file') {
      final filePath = uri.toFilePath(windows: Platform.isWindows);
      return _PreparedSocialUploadFile(
        filePath: filePath,
        deleteAfterUpload: false,
      );
    }
    if (scheme == 'http' || scheme == 'https') {
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 15);
      try {
        final request = await client.getUrl(uri);
        final response = await request.close();
        if (response.statusCode < 200 || response.statusCode >= 300) {
          return null;
        }
        final bytes = await consolidateHttpClientResponseBytes(response);
        final extension = _preferredUploadExtension(uri.path);
        final fileName =
            '$tempPrefix-${DateTime.now().microsecondsSinceEpoch}$extension';
        final filePath = path.join(Directory.systemTemp.path, fileName);
        final file = File(filePath);
        await file.writeAsBytes(bytes, flush: true);
        return _PreparedSocialUploadFile(
          filePath: file.path,
          deleteAfterUpload: true,
        );
      } finally {
        client.close(force: true);
      }
    }
  }

  return _PreparedSocialUploadFile(
    filePath: normalized,
    deleteAfterUpload: false,
  );
}

String _preferredUploadExtension(String rawPath) {
  final extension = path.extension(rawPath).toLowerCase();
  switch (extension) {
    case '.jpg':
    case '.jpeg':
    case '.png':
    case '.webp':
    case '.gif':
    case '.heic':
    case '.heif':
      return extension;
    default:
      return '.jpg';
  }
}

String? _replaceWishlistCoverImageUrl({
  required String? rawPlan,
  required String imageUrl,
}) {
  final raw = rawPlan?.trim();
  if (raw == null || raw.isEmpty) {
    return null;
  }
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      return rawPlan;
    }
    final payload = <String, dynamic>{
      for (final entry in decoded.entries) '${entry.key}': entry.value,
    };
    final currentCover = payload['cover_image'];
    final coverImage = currentCover is Map
        ? <String, dynamic>{
            for (final entry in currentCover.entries)
              '${entry.key}': entry.value,
          }
        : <String, dynamic>{};
    coverImage['image_url'] = imageUrl;
    payload['cover_image'] = coverImage;
    return jsonEncode(payload);
  } catch (_) {
    return rawPlan;
  }
}

class FriendsHubData {
  const FriendsHubData({
    required this.me,
    required this.friends,
  });

  final SocialMeData me;
  final List<FriendSummary> friends;
}

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

    final cached =
        state.valueOrNull ?? await _FriendsHubCacheStore.read(session.user.id);
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

final friendProfileProvider = FutureProvider.autoDispose
    .family<FriendProfileResponse, String>((ref, friendUserId) async {
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
  final coordinator = ref.watch(socialSyncControllerProvider);
  final lifecycleObserver = _SocialSyncLifecycleObserver(coordinator);
  WidgetsBinding.instance.addObserver(lifecycleObserver);
  ref.onDispose(() {
    WidgetsBinding.instance.removeObserver(lifecycleObserver);
  });

  ref.listen<AuthController>(authControllerProvider, (_, __) {
    coordinator.scheduleProfileSync();
    coordinator.scheduleTravelSync();
    coordinator.scheduleWishlistSync();
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
  ref.listen<AsyncValue<List<WishlistItemRecord>>>(wishlistStreamProvider,
      (_, __) {
    coordinator.scheduleTravelSync();
    coordinator.scheduleWishlistSync();
  });

  coordinator.scheduleProfileSync();
  coordinator.scheduleTravelSync();
  coordinator.scheduleWishlistSync();
});

final socialSyncControllerProvider = Provider<SocialSyncController>((ref) {
  final controller = SocialSyncController(ref);
  ref.onDispose(controller.dispose);
  return controller;
});

class _SocialSyncLifecycleObserver extends WidgetsBindingObserver {
  _SocialSyncLifecycleObserver(this._controller);

  final SocialSyncController _controller;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      unawaited(_controller.flushAllNow());
    }
  }
}

class SocialSyncController {
  SocialSyncController(this.ref);

  final Ref ref;
  Timer? _profileTimer;
  Timer? _travelTimer;
  Timer? _wishlistTimer;
  String? _lastProfileSignature;
  String? _lastTravelSignature;
  String? _lastWishlistSignature;
  String? _hydratedUserId;
  bool _didHydrateRemoteState = false;

  void scheduleProfileSync() {
    _profileTimer?.cancel();
    _profileTimer = Timer(
      const Duration(milliseconds: 250),
      () => unawaited(_syncProfile()),
    );
  }

  void scheduleTravelSync() {
    _travelTimer?.cancel();
    _travelTimer = Timer(
      const Duration(milliseconds: 300),
      () => unawaited(_syncTravel()),
    );
  }

  void scheduleWishlistSync() {
    _wishlistTimer?.cancel();
    _wishlistTimer = Timer(
      const Duration(milliseconds: 300),
      () => unawaited(_syncWishlist()),
    );
  }

  Future<void> flushTravelNow() async {
    _travelTimer?.cancel();
    await _syncTravel();
  }

  Future<void> flushWishlistNow() async {
    _wishlistTimer?.cancel();
    await _syncWishlist();
  }

  Future<void> flushAllNow() async {
    _profileTimer?.cancel();
    _travelTimer?.cancel();
    _wishlistTimer?.cancel();
    await _syncProfile();
    await _syncTravel();
    await _syncWishlist();
  }

  Future<void> _syncProfile() async {
    final session = ref.read(socialSessionProvider);
    if (session == null) {
      await _clearLocalUserData();
      _hydratedUserId = null;
      _didHydrateRemoteState = false;
      _lastProfileSignature = null;
      _lastTravelSignature = null;
      _lastWishlistSignature = null;
      return;
    }

    if (_hydratedUserId != session.user.id) {
      await _clearLocalUserData();
      _hydratedUserId = session.user.id;
      _didHydrateRemoteState = false;
      _lastProfileSignature = null;
      _lastTravelSignature = null;
      _lastWishlistSignature = null;
    }

    await _hydrateRemoteStateIfNeeded(session);

    final snapshot = ref.read(socialProfileSnapshotProvider);
    final signature = jsonEncode(snapshot.toJson());
    if (signature == _lastProfileSignature) {
      return;
    }

    try {
      final syncedProfile = await ref.read(socialApiClientProvider).syncProfile(
            accessToken: session.accessToken,
            profile: snapshot,
          );
      await ref.read(appPreferencesProvider.notifier).hydrateProfileCache(
            displayName: syncedProfile.displayName,
            homeBase: syncedProfile.homeBase,
            bio: syncedProfile.bio,
          );
      await ref.read(authControllerProvider).replaceLocalProfile(
            displayName: syncedProfile.displayName,
            photoUrl: syncedProfile.photoUrl,
            overwritePhotoUrl: true,
          );
      _lastProfileSignature = jsonEncode(syncedProfile.toJson());
      ref.invalidate(socialMeProvider);
      ref.invalidate(friendsHubProvider);
    } catch (error, stackTrace) {
      debugPrint('Social profile sync failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> _hydrateRemoteStateIfNeeded(SocialSession session) async {
    if (_didHydrateRemoteState) {
      return;
    }

    _didHydrateRemoteState = true;
    try {
      final localWishlistItems =
          await ref.read(wishlistRepositoryProvider).getWishlistItems();
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
          overwritePhotoUrl: true,
        );
      } else if (nextDisplayName !=
          (authController.currentUser?.displayName ?? '')) {
        await authController.replaceLocalProfile(
          displayName: nextDisplayName,
          photoUrl: '',
          overwritePhotoUrl: true,
        );
      }

      final syncedProfileSnapshot = SocialProfileSnapshot(
        displayName: nextDisplayName,
        photoUrl: remotePhotoUrl ?? authController.currentUser?.photoUrl,
        homeBase: remoteProfile.homeBase,
        bio: remoteProfile.bio,
      );
      _lastProfileSignature = jsonEncode(syncedProfileSnapshot.toJson());

      final shouldHydrateWishlist =
          localWishlistItems.isEmpty || me.wishlistItems.isNotEmpty;
      var effectiveWishlistItems = localWishlistItems;
      if (me.hasWishlistItemsPayload && shouldHydrateWishlist) {
        final localWishlistByKey = <String, WishlistItemRecord>{
          for (final item in localWishlistItems)
            _wishlistHydrationKey(item.remoteId, item.title): item,
        };
        await ref.read(wishlistRepositoryProvider).replaceWishlistItems(
          <WishlistItemRecord>[
            for (final item in me.wishlistItems)
              _wishlistRecordFromRemote(
                remote: item,
                local: localWishlistByKey[
                    _wishlistHydrationKey(item.id, item.title)],
              ),
          ],
        );
        effectiveWishlistItems =
            await ref.read(wishlistRepositoryProvider).getWishlistItems();
      }

      if (me.hasTripsPayload) {
        final wishlistRemoteIdToLocalId = <String, int>{
          for (final item in effectiveWishlistItems)
            if (item.id != null) _wishlistRemoteKey(item): item.id!,
        };
        await ref.read(tripsRepositoryProvider).replaceTrips(
          <TripRecord>[
            for (final trip in me.trips)
              TripRecord(
                remoteId: trip.id,
                countryCode: trip.countryCode.toUpperCase(),
                countryName: trip.countryName,
                startDate: trip.startDate,
                endDate: trip.endDate,
                cities: trip.cities,
                sourceWishlistItemId: trip.sourceWishlistItemId == null
                    ? null
                    : wishlistRemoteIdToLocalId[trip.sourceWishlistItemId!],
                cityDataJson: trip.cityEntries.isNotEmpty
                    ? jsonEncode(
                        trip.cityEntries
                            .map((entry) => entry.toJson())
                            .toList(growable: false),
                      )
                    : null,
                coverImageUri: trip.coverImageUrl,
                notes: trip.notes,
              ),
          ],
        );
      }

      if (me.hasVisitedCountriesPayload) {
        await ref.read(visitsRepositoryProvider).replaceVisits(
          <CountryVisitRecord>[
            for (final visit in me.visitedCountries)
              CountryVisitRecord(
                countryCode: visit.countryCode.toUpperCase(),
                countryName: visit.countryName,
                visitedAt: visit.visitedAt,
              ),
          ],
        );
      }

      if (me.hasTripsPayload || me.hasVisitedCountriesPayload) {
        _lastTravelSignature = jsonEncode(
          SocialTravelSnapshot(
            profile: syncedProfileSnapshot,
            trips: me.trips,
            visitedCountries: me.visitedCountries,
          ).toJson(),
        );
      }

      if (me.hasWishlistItemsPayload && shouldHydrateWishlist) {
        _lastWishlistSignature = jsonEncode(
          SocialWishlistSnapshot(items: me.wishlistItems).toJson(),
        );
      }

      ref.invalidate(socialMeProvider);
      ref.invalidate(friendsHubProvider);
    } catch (error, stackTrace) {
      debugPrint('Remote social state hydration failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> _syncTravel() async {
    final session = ref.read(socialSessionProvider);
    if (session == null) {
      return;
    }

    await _hydrateRemoteStateIfNeeded(session);
    await _promoteTripMedia(session);

    final snapshot = ref.read(socialTravelSnapshotProvider);
    if (snapshot == null) {
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

  Future<void> _syncWishlist() async {
    final session = ref.read(socialSessionProvider);
    if (session == null) {
      return;
    }

    await _hydrateRemoteStateIfNeeded(session);
    await _promoteWishlistMedia(session);

    final snapshot = ref.read(socialWishlistSnapshotProvider);
    if (snapshot == null) {
      return;
    }

    final signature = jsonEncode(snapshot.toJson());
    if (signature == _lastWishlistSignature) {
      return;
    }

    try {
      await ref.read(socialApiClientProvider).syncWishlist(
            accessToken: session.accessToken,
            wishlist: snapshot,
          );
      _lastWishlistSignature = signature;
      ref.invalidate(socialMeProvider);
      ref.invalidate(friendsHubProvider);
    } catch (error, stackTrace) {
      debugPrint('Social wishlist sync failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> _promoteTripMedia(SocialSession session) async {
    final api = ref.read(socialApiClientProvider);
    final repository = ref.read(tripsRepositoryProvider);
    final trips = await repository.getRecentTrips(limit: 5000);

    for (final trip in trips) {
      var nextTrip = trip;
      var didChange = false;

      final coverImage = normalizeSocialAssetUrl(trip.coverImageUri);
      if (coverImage != null &&
          coverImage.isNotEmpty &&
          !_isBackendManagedSocialImage(coverImage)) {
        final prepared = await _prepareSocialUploadFile(
          coverImage,
          tempPrefix: 'trip-cover',
        );
        if (prepared != null) {
          try {
            final uploadedUrl = await api.uploadTripCoverPhoto(
              accessToken: session.accessToken,
              tripId: _tripRemoteKey(trip),
              filePath: prepared.filePath,
            );
            if (uploadedUrl.isNotEmpty && uploadedUrl != trip.coverImageUri) {
              nextTrip = nextTrip.copyWith(coverImageUri: uploadedUrl);
              didChange = true;
            }
          } catch (error, stackTrace) {
            debugPrint('Trip cover upload failed: $error');
            debugPrintStack(stackTrace: stackTrace);
          } finally {
            await prepared.dispose();
          }
        }
      }

      final cityEntries = decodeTripCityEntries(
        cityDataJson: nextTrip.cityDataJson,
        legacyCities: nextTrip.cities,
      );
      var didChangeCities = false;
      final nextEntries = <TripCityEntry>[];
      for (final city in cityEntries) {
        final cityImage = normalizeSocialAssetUrl(city.imageUri);
        if (cityImage == null ||
            cityImage.isEmpty ||
            _isBackendManagedSocialImage(cityImage)) {
          nextEntries.add(city);
          continue;
        }

        final prepared = await _prepareSocialUploadFile(
          cityImage,
          tempPrefix: 'trip-city',
        );
        if (prepared == null) {
          nextEntries.add(city);
          continue;
        }

        try {
          final uploadedUrl = await api.uploadTripCityPhoto(
            accessToken: session.accessToken,
            tripId: _tripRemoteKey(trip),
            cityKey: _slugifyCityKey(city.name),
            filePath: prepared.filePath,
          );
          if (uploadedUrl.isNotEmpty && uploadedUrl != city.imageUri) {
            nextEntries.add(city.copyWith(imageUri: uploadedUrl));
            didChangeCities = true;
          } else {
            nextEntries.add(city);
          }
        } catch (error, stackTrace) {
          debugPrint('Trip city image upload failed: $error');
          debugPrintStack(stackTrace: stackTrace);
          nextEntries.add(city);
        } finally {
          await prepared.dispose();
        }
      }

      if (didChangeCities) {
        nextTrip = nextTrip.copyWith(
          cityDataJson: encodeTripCityEntries(nextEntries),
        );
        didChange = true;
      }

      if (didChange) {
        await repository.updateTrip(nextTrip);
      }
    }
  }

  Future<void> _promoteWishlistMedia(SocialSession session) async {
    final api = ref.read(socialApiClientProvider);
    final repository = ref.read(wishlistRepositoryProvider);
    final items = await repository.getWishlistItems();

    for (final item in items) {
      final image = normalizeSocialAssetUrl(wishlistPrimaryImageUrl(item));
      if (image == null ||
          image.isEmpty ||
          _isBackendManagedSocialImage(image)) {
        continue;
      }

      final prepared = await _prepareSocialUploadFile(
        image,
        tempPrefix: 'wishlist-cover',
      );
      if (prepared == null) {
        continue;
      }

      try {
        final uploadedUrl = await api.uploadWishlistPhoto(
          accessToken: session.accessToken,
          wishlistItemId: _wishlistRemoteKey(item),
          filePath: prepared.filePath,
        );
        if (uploadedUrl.isEmpty) {
          continue;
        }
        final updatedPlan = _replaceWishlistCoverImageUrl(
          rawPlan: item.aiPlan,
          imageUrl: uploadedUrl,
        );
        if (updatedPlan != item.aiPlan) {
          await repository.updateWishlistItem(
            item.copyWith(aiPlan: updatedPlan),
          );
        }
      } catch (error, stackTrace) {
        debugPrint('Wishlist image upload failed: $error');
        debugPrintStack(stackTrace: stackTrace);
      } finally {
        await prepared.dispose();
      }
    }
  }

  Future<void> _clearLocalUserData() async {
    await ref.read(databaseProvider).clearSocialData();
    await ref.read(appPreferencesProvider.notifier).clearProfileCache();
    _FriendsHubCacheStore.clearAll();
    ref.invalidate(socialMeProvider);
    ref.invalidate(friendsHubProvider);
  }

  void dispose() {
    _profileTimer?.cancel();
    _travelTimer?.cancel();
    _wishlistTimer?.cancel();
  }
}

WishlistItemRecord _wishlistRecordFromRemote({
  required SocialWishlistItem remote,
  required WishlistItemRecord? local,
}) {
  final mergedAiPlan = _mergeWishlistAiPlan(
    localAiPlan: local?.aiPlan,
    remoteAiPlan: _nonEmptyOrNull(remote.aiPlan),
    remoteImageUrl: remote.imageUrl,
  );
  return WishlistItemRecord(
    remoteId: remote.id,
    title: remote.title,
    countryName: _nonEmptyOrNull(remote.countryName) ?? local?.countryName,
    countryCode: _nonEmptyOrNull(remote.countryCode) ?? local?.countryCode,
    createdAt:
        remote.createdAt > 0 ? remote.createdAt : (local?.createdAt ?? 0),
    plannedStartDate: remote.plannedStartDate ?? local?.plannedStartDate,
    plannedEndDate: remote.plannedEndDate ?? local?.plannedEndDate,
    plannedCities:
        _nonEmptyOrNull(remote.plannedCities) ?? local?.plannedCities,
    aiPlan: mergedAiPlan,
    isPinned: remote.isPinned,
  );
}

String _wishlistHydrationKey(String? remoteId, String title) {
  final normalizedRemoteId = remoteId?.trim();
  if (normalizedRemoteId != null && normalizedRemoteId.isNotEmpty) {
    return 'remote:$normalizedRemoteId';
  }
  final normalizedTitle = title
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  return 'title:$normalizedTitle';
}

String? _mergeWishlistAiPlan({
  required String? localAiPlan,
  required String? remoteAiPlan,
  required String? remoteImageUrl,
}) {
  final normalizedRemoteImage = normalizeSocialAssetUrl(remoteImageUrl);
  String? basePlan =
      _nonEmptyOrNull(remoteAiPlan) ?? _nonEmptyOrNull(localAiPlan);
  if (basePlan == null && normalizedRemoteImage == null) {
    return null;
  }

  if (basePlan == null && normalizedRemoteImage != null) {
    return jsonEncode(<String, dynamic>{
      'cover_image': <String, dynamic>{
        'image_url': normalizedRemoteImage,
      },
    });
  }

  try {
    final decoded = jsonDecode(basePlan!);
    if (decoded is! Map) {
      return basePlan;
    }
    final payload = <String, dynamic>{
      for (final entry in decoded.entries) '${entry.key}': entry.value,
    };
    if (normalizedRemoteImage != null) {
      final currentCover = payload['cover_image'];
      final coverImage = currentCover is Map
          ? <String, dynamic>{
              for (final entry in currentCover.entries)
                '${entry.key}': entry.value,
            }
          : <String, dynamic>{};
      coverImage['image_url'] = normalizedRemoteImage;
      payload['cover_image'] = coverImage;
    }
    return jsonEncode(payload);
  } catch (_) {
    return basePlan;
  }
}

class _FriendsHubCacheStore {
  const _FriendsHubCacheStore._();

  static final Map<String, _FriendsHubCacheEntry> _entries =
      <String, _FriendsHubCacheEntry>{};

  static Future<FriendsHubData?> read(String userId) async {
    final cached = _entries[userId];
    if (cached == null) {
      return null;
    }
    if (DateTime.now().difference(cached.cachedAt) > _friendsHubCacheMaxAge) {
      _entries.remove(userId);
      return null;
    }
    return cached.data;
  }

  static Future<void> write(String userId, FriendsHubData data) async {
    _entries[userId] = _FriendsHubCacheEntry(
      data: data,
      cachedAt: DateTime.now(),
    );
  }

  static void clearAll() {
    _entries.clear();
  }
}

class _FriendsHubCacheEntry {
  const _FriendsHubCacheEntry({
    required this.data,
    required this.cachedAt,
  });

  final FriendsHubData data;
  final DateTime cachedAt;
}
