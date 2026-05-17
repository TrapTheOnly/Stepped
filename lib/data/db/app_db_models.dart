const _noWishlistValue = Object();

class CountryVisitRecord {
  const CountryVisitRecord({
    required this.countryCode,
    required this.countryName,
    required this.visitedAt,
  });

  final String countryCode;
  final String countryName;
  final int visitedAt;

  factory CountryVisitRecord.fromMap(Map<String, Object?> map) {
    return CountryVisitRecord(
      countryCode: map['countryCode'] as String,
      countryName: map['countryName'] as String,
      visitedAt: map['visitedAt'] as int,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'countryCode': countryCode,
      'countryName': countryName,
      'visitedAt': visitedAt,
    };
  }
}

class TripRecord {
  const TripRecord({
    this.id,
    this.remoteId,
    required this.countryCode,
    required this.countryName,
    required this.startDate,
    required this.endDate,
    required this.cities,
    this.sourceWishlistItemId,
    this.cityDataJson,
    this.coverImageUri,
    this.notes,
  });

  final int? id;
  final String? remoteId;
  final String countryCode;
  final String countryName;
  final int startDate;
  final int endDate;
  final String cities;
  final int? sourceWishlistItemId;
  final String? cityDataJson;
  final String? coverImageUri;
  final String? notes;

  factory TripRecord.fromMap(Map<String, Object?> map) {
    return TripRecord(
      id: map['id'] as int,
      remoteId: map['remoteId'] as String?,
      countryCode: map['countryCode'] as String,
      countryName: map['countryName'] as String,
      startDate: map['startDate'] as int,
      endDate: map['endDate'] as int,
      cities: map['cities'] as String,
      sourceWishlistItemId: map['sourceWishlistItemId'] as int?,
      cityDataJson: map['cityDataJson'] as String?,
      coverImageUri: map['coverImageUri'] as String?,
      notes: map['notes'] as String?,
    );
  }

  TripRecord copyWith({
    int? id,
    Object? remoteId = _noWishlistValue,
    String? countryCode,
    String? countryName,
    int? startDate,
    int? endDate,
    String? cities,
    Object? sourceWishlistItemId = _noWishlistValue,
    Object? cityDataJson = _noWishlistValue,
    String? coverImageUri,
    String? notes,
  }) {
    return TripRecord(
      id: id ?? this.id,
      remoteId: identical(remoteId, _noWishlistValue)
          ? this.remoteId
          : remoteId as String?,
      countryCode: countryCode ?? this.countryCode,
      countryName: countryName ?? this.countryName,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      cities: cities ?? this.cities,
      sourceWishlistItemId: identical(sourceWishlistItemId, _noWishlistValue)
          ? this.sourceWishlistItemId
          : sourceWishlistItemId as int?,
      cityDataJson: identical(cityDataJson, _noWishlistValue)
          ? this.cityDataJson
          : cityDataJson as String?,
      coverImageUri: coverImageUri ?? this.coverImageUri,
      notes: notes ?? this.notes,
    );
  }

  Map<String, Object?> toMap({bool includeId = false}) {
    final data = <String, Object?>{
      'remoteId': remoteId,
      'countryCode': countryCode,
      'countryName': countryName,
      'startDate': startDate,
      'endDate': endDate,
      'cities': cities,
      'sourceWishlistItemId': sourceWishlistItemId,
      'cityDataJson': cityDataJson,
      'coverImageUri': coverImageUri,
      'notes': notes,
    };

    if (includeId && id != null) {
      data['id'] = id;
    }

    return data;
  }
}

class WishlistItemRecord {
  const WishlistItemRecord({
    this.id,
    this.remoteId,
    required this.title,
    this.countryName,
    this.countryCode,
    required this.createdAt,
    this.plannedStartDate,
    this.plannedEndDate,
    this.plannedCities,
    this.aiPlan,
    this.isPinned = false,
  });

  final int? id;
  final String? remoteId;
  final String title;
  final String? countryName;
  final String? countryCode;
  final int createdAt;
  final int? plannedStartDate;
  final int? plannedEndDate;
  final String? plannedCities;
  final String? aiPlan;
  final bool isPinned;

  factory WishlistItemRecord.fromMap(Map<String, Object?> map) {
    return WishlistItemRecord(
      id: map['id'] as int,
      remoteId: map['remoteId'] as String?,
      title: map['title'] as String,
      countryName: map['countryName'] as String?,
      countryCode: map['countryCode'] as String?,
      createdAt: map['createdAt'] as int,
      plannedStartDate: map['plannedStartDate'] as int?,
      plannedEndDate: map['plannedEndDate'] as int?,
      plannedCities: map['plannedCities'] as String?,
      aiPlan: map['aiPlan'] as String?,
      isPinned: ((map['isPinned'] as int?) ?? 0) != 0,
    );
  }

  WishlistItemRecord copyWith({
    int? id,
    Object? remoteId = _noWishlistValue,
    String? title,
    Object? countryName = _noWishlistValue,
    Object? countryCode = _noWishlistValue,
    int? createdAt,
    Object? plannedStartDate = _noWishlistValue,
    Object? plannedEndDate = _noWishlistValue,
    Object? plannedCities = _noWishlistValue,
    Object? aiPlan = _noWishlistValue,
    Object? isPinned = _noWishlistValue,
  }) {
    return WishlistItemRecord(
      id: id ?? this.id,
      remoteId: identical(remoteId, _noWishlistValue)
          ? this.remoteId
          : remoteId as String?,
      title: title ?? this.title,
      countryName: identical(countryName, _noWishlistValue)
          ? this.countryName
          : countryName as String?,
      countryCode: identical(countryCode, _noWishlistValue)
          ? this.countryCode
          : countryCode as String?,
      createdAt: createdAt ?? this.createdAt,
      plannedStartDate: identical(plannedStartDate, _noWishlistValue)
          ? this.plannedStartDate
          : plannedStartDate as int?,
      plannedEndDate: identical(plannedEndDate, _noWishlistValue)
          ? this.plannedEndDate
          : plannedEndDate as int?,
      plannedCities: identical(plannedCities, _noWishlistValue)
          ? this.plannedCities
          : plannedCities as String?,
      aiPlan:
          identical(aiPlan, _noWishlistValue) ? this.aiPlan : aiPlan as String?,
      isPinned: identical(isPinned, _noWishlistValue)
          ? this.isPinned
          : isPinned as bool,
    );
  }

  Map<String, Object?> toMap({bool includeId = false}) {
    final data = <String, Object?>{
      'remoteId': remoteId,
      'title': title,
      'countryName': countryName,
      'countryCode': countryCode,
      'createdAt': createdAt,
      'plannedStartDate': plannedStartDate,
      'plannedEndDate': plannedEndDate,
      'plannedCities': plannedCities,
      'aiPlan': aiPlan,
      'isPinned': isPinned ? 1 : 0,
    };

    if (includeId && id != null) {
      data['id'] = id;
    }

    return data;
  }
}
