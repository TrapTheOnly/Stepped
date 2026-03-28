import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

final friendsHubProvider = FutureProvider<FriendsHubData>((ref) async {
  final session = ref.watch(socialSessionProvider);
  if (session == null) {
    throw const SocialApiException(
      'You need to sign in to use social features.',
      statusCode: 401,
    );
  }

  final client = ref.watch(socialApiClientProvider);
  final results = await Future.wait<Object>(<Future<Object>>[
    client.getCurrentSocialState(accessToken: session.accessToken),
    client.getFriends(accessToken: session.accessToken),
  ]);
  final me = results[0] as SocialMeData;
  final friends = results[1] as List<FriendSummary>;
  return FriendsHubData(me: me, friends: friends);
});

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
      return;
    }

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
