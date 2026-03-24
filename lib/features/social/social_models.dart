import '../trips/trip_city_models.dart';

class SocialProfileSnapshot {
  const SocialProfileSnapshot({
    required this.displayName,
    required this.photoUrl,
    required this.homeBase,
    required this.bio,
  });

  final String displayName;
  final String? photoUrl;
  final String homeBase;
  final String bio;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'display_name': displayName,
      'photo_url': photoUrl,
      'home_base': homeBase,
      'bio': bio,
    };
  }

  factory SocialProfileSnapshot.fromJson(dynamic raw) {
    final json = _asMap(raw);
    return SocialProfileSnapshot(
      displayName: _firstNonEmptyString(<dynamic>[
            json['display_name'],
            json['displayName'],
            json['name'],
            'Traveler',
          ]) ??
          'Traveler',
      photoUrl: _firstNonEmptyString(<dynamic>[
        json['photo_url'],
        json['photoUrl'],
      ]),
      homeBase: _firstNonEmptyString(<dynamic>[
            json['home_base'],
            json['homeBase'],
            json['location'],
          ]) ??
          '',
      bio: _firstNonEmptyString(<dynamic>[
            json['bio'],
            json['about'],
          ]) ??
          '',
    );
  }
}

class SocialTravelSnapshot {
  const SocialTravelSnapshot({
    required this.profile,
    required this.trips,
    required this.visitedCountries,
  });

  final SocialProfileSnapshot profile;
  final List<SocialTripSummary> trips;
  final List<SocialVisitedCountry> visitedCountries;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'profile': profile.toJson(),
      'trips': <Map<String, dynamic>>[
        for (final trip in trips) trip.toJson(),
      ],
      'visited_countries': <Map<String, dynamic>>[
        for (final country in visitedCountries) country.toJson(),
      ],
    };
  }
}

class SocialTripSummary {
  const SocialTripSummary({
    required this.id,
    required this.countryCode,
    required this.countryName,
    required this.startDate,
    required this.endDate,
    required this.cities,
    this.cityEntries = const <TripCityEntry>[],
    this.coverImageUrl,
    this.notes,
  });

  final String id;
  final String countryCode;
  final String countryName;
  final int startDate;
  final int endDate;
  final String cities;
  final List<TripCityEntry> cityEntries;
  final String? coverImageUrl;
  final String? notes;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'country_code': countryCode,
      'country_name': countryName,
      'start_date': startDate,
      'end_date': endDate,
      'cities': cities,
      'city_entries': cityEntries
          .map((entry) => entry.toJson())
          .toList(growable: false),
      'cover_image_url': coverImageUrl,
      'notes': notes,
    };
  }

  factory SocialTripSummary.fromJson(dynamic raw) {
    final json = _asMap(raw);
    final cityEntries = _readTripCityEntries(json);
    return SocialTripSummary(
      id: _firstNonEmptyString(<dynamic>[json['id'], json['trip_id']]) ?? '',
      countryCode: _firstNonEmptyString(<dynamic>[
            json['country_code'],
            json['countryCode'],
          ]) ??
          '',
      countryName: _firstNonEmptyString(<dynamic>[
            json['country_name'],
            json['countryName'],
          ]) ??
          '',
      startDate: _readEpochMillis(<dynamic>[
            json['start_date'],
            json['startDate'],
          ]) ??
          0,
      endDate: _readEpochMillis(<dynamic>[
            json['end_date'],
            json['endDate'],
          ]) ??
          0,
      cities: _firstNonEmptyString(<dynamic>[
            json['cities'],
            if (cityEntries.isNotEmpty)
              cityEntries.map((entry) => entry.name).join(', '),
          ]) ??
          '',
      cityEntries: cityEntries,
      coverImageUrl: _firstNonEmptyString(<dynamic>[
        json['cover_image_url'],
        json['coverImageUrl'],
      ]),
      notes: _firstNonEmptyString(<dynamic>[json['notes']]),
    );
  }
}

class SocialVisitedCountry {
  const SocialVisitedCountry({
    required this.countryCode,
    required this.countryName,
    required this.visitedAt,
  });

  final String countryCode;
  final String countryName;
  final int visitedAt;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'country_code': countryCode,
      'country_name': countryName,
      'visited_at': visitedAt,
    };
  }

  factory SocialVisitedCountry.fromJson(dynamic raw) {
    final json = _asMap(raw);
    return SocialVisitedCountry(
      countryCode: _firstNonEmptyString(<dynamic>[
            json['country_code'],
            json['countryCode'],
          ]) ??
          '',
      countryName: _firstNonEmptyString(<dynamic>[
            json['country_name'],
            json['countryName'],
          ]) ??
          '',
      visitedAt: _readEpochMillis(<dynamic>[
            json['visited_at'],
            json['visitedAt'],
          ]) ??
          0,
    );
  }
}

class SocialInviteLink {
  const SocialInviteLink({
    required this.token,
    required this.url,
    required this.status,
    this.createdAt,
  });

  final String token;
  final String url;
  final String status;
  final DateTime? createdAt;

  bool get isActive {
    switch (status.toLowerCase()) {
      case 'active':
      case 'open':
      case 'current':
        return true;
      default:
        return false;
    }
  }

  String get shortStatusLabel {
    switch (status.toLowerCase()) {
      case 'active':
      case 'open':
      case 'current':
        return 'Active';
      case 'used':
        return 'Used';
      case 'expired':
        return 'Expired';
      case 'revoked':
      case 'inactive':
        return 'Inactive';
      default:
        if (status.trim().isEmpty) {
          return 'Unknown';
        }
        final normalized = status.replaceAll('_', ' ').trim();
        return normalized[0].toUpperCase() + normalized.substring(1);
    }
  }

  String get shareUrl {
    final normalizedToken = token.trim();
    if (normalizedToken.isEmpty) {
      return url;
    }
    return 'https://app.stepped.world/friends/add/$normalizedToken';
  }

  String get deepLinkUrl {
    final normalizedToken = token.trim();
    if (normalizedToken.isEmpty) {
      return url;
    }
    return 'stepped://friends/add/$normalizedToken';
  }

  factory SocialInviteLink.fromJson(dynamic raw) {
    final json = _asMap(raw);
    return SocialInviteLink(
      token: _firstNonEmptyString(<dynamic>[json['token']]) ?? '',
      url: _firstNonEmptyString(<dynamic>[json['url']]) ?? '',
      status: _firstNonEmptyString(<dynamic>[json['status']]) ?? 'unknown',
      createdAt: _readDateTime(<dynamic>[
        json['created_at'],
        json['createdAt'],
        json['updated_at'],
        json['updatedAt'],
      ]),
    );
  }
}

class SocialStats {
  const SocialStats({
    required this.totalTrips,
    required this.visitedCountriesCount,
    required this.totalFriends,
  });

  final int totalTrips;
  final int visitedCountriesCount;
  final int totalFriends;

  factory SocialStats.fromJson(dynamic raw) {
    final json = _asMap(raw);
    return SocialStats(
      totalTrips: _readInt(<dynamic>[
            json['total_trips'],
            json['totalTrips'],
          ]) ??
          0,
      visitedCountriesCount: _readInt(<dynamic>[
            json['visited_countries_count'],
            json['visitedCountriesCount'],
          ]) ??
          0,
      totalFriends: _readInt(<dynamic>[
            json['total_friends'],
            json['totalFriends'],
            json['friends_count'],
            json['friendCount'],
          ]) ??
          0,
    );
  }
}

class SocialMeData {
  const SocialMeData({
    required this.profile,
    this.invite,
    this.stats,
    this.invites = const <SocialInviteLink>[],
  });

  final SocialProfileSnapshot profile;
  final SocialInviteLink? invite;
  final SocialStats? stats;
  final List<SocialInviteLink> invites;

  factory SocialMeData.fromJson(dynamic raw) {
    final json = _asMap(raw);
    final profileRaw = json['profile'] ?? json['me'] ?? json['user'] ?? json;
    final inviteRaw = json['invite'] ??
        json['active_invite'] ??
        json['friend_invite'] ??
        (json['invites'] is List && (json['invites'] as List).isNotEmpty
            ? (json['invites'] as List).first
            : null);
    final statsRaw = json['stats'] ?? json['counts'];
    final inviteListRaw = json['invites'];
    final parsedInvites = <SocialInviteLink>[
      if (inviteListRaw is List)
        for (final entry in inviteListRaw) SocialInviteLink.fromJson(entry),
      if (inviteRaw != null) SocialInviteLink.fromJson(inviteRaw),
    ];
    final invites = _dedupeInviteLinks(parsedInvites);

    return SocialMeData(
      profile: SocialProfileSnapshot.fromJson(profileRaw),
      invite: _selectPrimaryInvite(invites),
      stats: statsRaw == null ? null : SocialStats.fromJson(statsRaw),
      invites: invites,
    );
  }
}

class FriendSummary {
  const FriendSummary({
    required this.id,
    required this.displayName,
    this.photoUrl,
    required this.homeBase,
    this.addedAt,
  });

  final String id;
  final String displayName;
  final String? photoUrl;
  final String homeBase;
  final DateTime? addedAt;

  factory FriendSummary.fromJson(dynamic raw) {
    final json = _asMap(raw);
    return FriendSummary(
      id: _firstNonEmptyString(<dynamic>[json['id'], json['user_id']]) ?? '',
      displayName: _firstNonEmptyString(<dynamic>[
            json['display_name'],
            json['displayName'],
            json['name'],
            'Traveler',
          ]) ??
          'Traveler',
      photoUrl: _firstNonEmptyString(<dynamic>[
        json['photo_url'],
        json['photoUrl'],
      ]),
      homeBase: _firstNonEmptyString(<dynamic>[
            json['home_base'],
            json['homeBase'],
          ]) ??
          '',
      addedAt: _readDateTime(<dynamic>[
        json['added_at'],
        json['addedAt'],
      ]),
    );
  }
}

class FriendInvitePreview {
  const FriendInvitePreview({
    required this.token,
    required this.inviterName,
    required this.inviterEmail,
    this.inviterPhotoUrl,
    required this.inviterHomeBase,
    required this.canAccept,
    required this.status,
  });

  final String token;
  final String inviterName;
  final String inviterEmail;
  final String? inviterPhotoUrl;
  final String inviterHomeBase;
  final bool canAccept;
  final String status;

  factory FriendInvitePreview.fromJson(dynamic raw, String fallbackToken) {
    final json = _asMap(raw);
    final inviter = _asMapOrNull(
          json['inviter'] ?? json['friend'] ?? json['profile'] ?? json['user'],
        ) ??
        json;
    final invite = _asMapOrNull(json['invite']) ?? json;
    final status = _firstNonEmptyString(<dynamic>[
          invite['status'],
          json['status'],
          json['invite_status'],
        ]) ??
        'unknown';
    final canAccept = _readBool(<dynamic>[
          json['can_accept'],
          json['canAccept'],
          invite['can_accept'],
          invite['canAccept'],
        ]) ??
        !(status == 'used' ||
            status == 'accepted' ||
            status == 'expired' ||
            status == 'already_friends' ||
            status == 'self');

    return FriendInvitePreview(
      token: _firstNonEmptyString(<dynamic>[invite['token'], json['token']]) ??
          fallbackToken,
      inviterName: _firstNonEmptyString(<dynamic>[
            inviter['display_name'],
            inviter['displayName'],
            inviter['name'],
            'Traveler',
          ]) ??
          'Traveler',
      inviterEmail: _firstNonEmptyString(<dynamic>[
            inviter['email'],
            inviter['email_address'],
            inviter['emailAddress'],
            json['email'],
          ]) ??
          '',
      inviterPhotoUrl: _firstNonEmptyString(<dynamic>[
        inviter['photo_url'],
        inviter['photoUrl'],
      ]),
      inviterHomeBase: _firstNonEmptyString(<dynamic>[
            inviter['home_base'],
            inviter['homeBase'],
          ]) ??
          '',
      canAccept: canAccept,
      status: status,
    );
  }
}

class FriendAcceptResult {
  const FriendAcceptResult({
    required this.friend,
    required this.accepted,
  });

  final FriendSummary friend;
  final bool accepted;

  factory FriendAcceptResult.fromJson(dynamic raw) {
    final json = _asMap(raw);
    return FriendAcceptResult(
      friend: FriendSummary.fromJson(json['friend'] ?? json),
      accepted: _readBool(<dynamic>[json['accepted']]) ?? false,
    );
  }
}

class FriendProfile {
  const FriendProfile({
    required this.id,
    required this.displayName,
    this.photoUrl,
    required this.homeBase,
    required this.bio,
    required this.stats,
    required this.visitedCountries,
  });

  final String id;
  final String displayName;
  final String? photoUrl;
  final String homeBase;
  final String bio;
  final SocialStats stats;
  final List<SocialVisitedCountry> visitedCountries;

  factory FriendProfile.fromJson(dynamic raw) {
    final json = _asMap(raw);
    final statsRaw = json['stats'] ?? json['counts'] ?? const <String, dynamic>{};
    final visitedRaw = _asList(json['visited_countries']);
    return FriendProfile(
      id: _firstNonEmptyString(<dynamic>[json['id'], json['user_id']]) ?? '',
      displayName: _firstNonEmptyString(<dynamic>[
            json['display_name'],
            json['displayName'],
            json['name'],
            'Traveler',
          ]) ??
          'Traveler',
      photoUrl: _firstNonEmptyString(<dynamic>[
        json['photo_url'],
        json['photoUrl'],
      ]),
      homeBase: _firstNonEmptyString(<dynamic>[
            json['home_base'],
            json['homeBase'],
          ]) ??
          '',
      bio: _firstNonEmptyString(<dynamic>[json['bio']]) ?? '',
      stats: SocialStats.fromJson(statsRaw),
      visitedCountries: <SocialVisitedCountry>[
        for (final entry in visitedRaw) SocialVisitedCountry.fromJson(entry),
      ],
    );
  }
}

class FriendProfileResponse {
  const FriendProfileResponse({
    required this.friend,
    required this.trips,
  });

  final FriendProfile friend;
  final List<SocialTripSummary> trips;

  factory FriendProfileResponse.fromJson(dynamic raw) {
    final json = _asMap(raw);
    final tripsRaw = _asList(json['trips']);
    return FriendProfileResponse(
      friend: FriendProfile.fromJson(json['friend'] ?? json),
      trips: <SocialTripSummary>[
        for (final entry in tripsRaw) SocialTripSummary.fromJson(entry),
      ],
    );
  }
}

Map<String, dynamic> _asMap(dynamic raw) {
  final map = _asMapOrNull(raw);
  if (map == null) {
    throw const FormatException('Expected a JSON object.');
  }
  return map;
}

List<SocialInviteLink> _dedupeInviteLinks(List<SocialInviteLink> invites) {
  final deduped = <SocialInviteLink>[];
  final seenTokens = <String>{};
  for (final invite in invites) {
    final normalizedToken = invite.token.trim();
    if (normalizedToken.isEmpty || seenTokens.contains(normalizedToken)) {
      continue;
    }
    seenTokens.add(normalizedToken);
    deduped.add(invite);
  }
  return deduped;
}

SocialInviteLink? _selectPrimaryInvite(List<SocialInviteLink> invites) {
  if (invites.isEmpty) {
    return null;
  }

  final sorted = <SocialInviteLink>[...invites]
    ..sort((a, b) {
      final activeComparison =
          (b.isActive ? 1 : 0).compareTo(a.isActive ? 1 : 0);
      if (activeComparison != 0) {
        return activeComparison;
      }
      final aCreatedAt = a.createdAt;
      final bCreatedAt = b.createdAt;
      if (aCreatedAt == null && bCreatedAt == null) {
        return 0;
      }
      if (aCreatedAt == null) {
        return 1;
      }
      if (bCreatedAt == null) {
        return -1;
      }
      return bCreatedAt.compareTo(aCreatedAt);
    });
  return sorted.first;
}

List<TripCityEntry> _readTripCityEntries(Map<String, dynamic> json) {
  final cityEntriesRaw = json['city_entries'] ?? json['cityEntries'];
  if (cityEntriesRaw is List) {
    return sanitizeTripCityEntries(
      cityEntriesRaw
          .whereType<Map>()
          .map(
            (entry) => TripCityEntry.fromJson(
              Map<String, dynamic>.from(entry.cast<String, dynamic>()),
            ),
          )
          .toList(growable: false),
    );
  }

  final cityDataJson = _firstNonEmptyString(<dynamic>[
    json['city_data_json'],
    json['cityDataJson'],
  ]);
  return decodeTripCityEntries(
    cityDataJson: cityDataJson,
    legacyCities: _firstNonEmptyString(<dynamic>[json['cities']]) ?? '',
  );
}

Map<String, dynamic>? _asMapOrNull(dynamic raw) {
  if (raw is Map<String, dynamic>) {
    return raw;
  }
  if (raw is Map) {
    return <String, dynamic>{
      for (final entry in raw.entries) '${entry.key}': entry.value,
    };
  }
  return null;
}

List<dynamic> _asList(dynamic raw) {
  if (raw is List) {
    return raw;
  }
  return const <dynamic>[];
}

String? _firstNonEmptyString(List<dynamic> values) {
  for (final value in values) {
    if (value is! String) {
      continue;
    }
    final normalized = value.trim();
    if (normalized.isNotEmpty) {
      return normalized;
    }
  }
  return null;
}

int? _readEpochMillis(List<dynamic> values) {
  for (final value in values) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      final numeric = int.tryParse(value.trim());
      if (numeric != null) {
        return numeric;
      }
      final date = DateTime.tryParse(value.trim());
      if (date != null) {
        return date.millisecondsSinceEpoch;
      }
    }
  }
  return null;
}

int? _readInt(List<dynamic> values) {
  for (final value in values) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      final numeric = int.tryParse(value.trim());
      if (numeric != null) {
        return numeric;
      }
    }
  }
  return null;
}

bool? _readBool(List<dynamic> values) {
  for (final value in values) {
    if (value is bool) {
      return value;
    }
    if (value is num) {
      return value != 0;
    }
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      if (normalized == 'true') {
        return true;
      }
      if (normalized == 'false') {
        return false;
      }
    }
  }
  return null;
}

DateTime? _readDateTime(List<dynamic> values) {
  for (final value in values) {
    if (value is DateTime) {
      return value;
    }
    if (value is String) {
      final parsed = DateTime.tryParse(value.trim());
      if (parsed != null) {
        return parsed;
      }
    }
    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value);
    }
    if (value is num) {
      return DateTime.fromMillisecondsSinceEpoch(value.toInt());
    }
  }
  return null;
}
