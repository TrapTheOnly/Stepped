import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'tables.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  final database = AppDatabase();
  ref.onDispose(database.close);
  return database;
});

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
    required this.countryCode,
    required this.countryName,
    required this.startDate,
    required this.endDate,
    required this.cities,
    this.coverImageUri,
    this.notes,
  });

  final int? id;
  final String countryCode;
  final String countryName;
  final int startDate;
  final int endDate;
  final String cities;
  final String? coverImageUri;
  final String? notes;

  factory TripRecord.fromMap(Map<String, Object?> map) {
    return TripRecord(
      id: map['id'] as int,
      countryCode: map['countryCode'] as String,
      countryName: map['countryName'] as String,
      startDate: map['startDate'] as int,
      endDate: map['endDate'] as int,
      cities: map['cities'] as String,
      coverImageUri: map['coverImageUri'] as String?,
      notes: map['notes'] as String?,
    );
  }

  TripRecord copyWith({
    int? id,
    String? countryCode,
    String? countryName,
    int? startDate,
    int? endDate,
    String? cities,
    String? coverImageUri,
    String? notes,
  }) {
    return TripRecord(
      id: id ?? this.id,
      countryCode: countryCode ?? this.countryCode,
      countryName: countryName ?? this.countryName,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      cities: cities ?? this.cities,
      coverImageUri: coverImageUri ?? this.coverImageUri,
      notes: notes ?? this.notes,
    );
  }

  Map<String, Object?> toMap({bool includeId = false}) {
    final data = <String, Object?>{
      'countryCode': countryCode,
      'countryName': countryName,
      'startDate': startDate,
      'endDate': endDate,
      'cities': cities,
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
    required this.title,
    this.countryName,
    required this.createdAt,
  });

  final int? id;
  final String title;
  final String? countryName;
  final int createdAt;

  factory WishlistItemRecord.fromMap(Map<String, Object?> map) {
    return WishlistItemRecord(
      id: map['id'] as int,
      title: map['title'] as String,
      countryName: map['countryName'] as String?,
      createdAt: map['createdAt'] as int,
    );
  }

  WishlistItemRecord copyWith({
    int? id,
    String? title,
    String? countryName,
    int? createdAt,
  }) {
    return WishlistItemRecord(
      id: id ?? this.id,
      title: title ?? this.title,
      countryName: countryName ?? this.countryName,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, Object?> toMap({bool includeId = false}) {
    final data = <String, Object?>{
      'title': title,
      'countryName': countryName,
      'createdAt': createdAt,
    };

    if (includeId && id != null) {
      data['id'] = id;
    }

    return data;
  }
}

class AppDatabase {
  static const _databaseName = 'stepped.db';
  static const _databaseVersion = 1;

  Database? _database;
  final StreamController<void> _tripChanges =
      StreamController<void>.broadcast(sync: true);
  final StreamController<void> _visitChanges =
      StreamController<void>.broadcast(sync: true);
  final StreamController<void> _wishlistChanges =
      StreamController<void>.broadcast(sync: true);

  Future<Database> get _db async {
    final existing = _database;
    if (existing != null) {
      return existing;
    }

    final path = p.join(await getDatabasesPath(), _databaseName);
    final created = await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: (db, _) async {
        await db.execute(createCountryVisitsTable);
        await db.execute(createTripsTable);
        await db.execute(createWishlistTable);
        await db.execute(createTripsStartDateIndex);
        await db.execute(createWishlistCreatedAtIndex);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 1) {
          await db.execute(createCountryVisitsTable);
          await db.execute(createTripsTable);
          await db.execute(createWishlistTable);
          await db.execute(createTripsStartDateIndex);
          await db.execute(createWishlistCreatedAtIndex);
        }
      },
    );

    _database = created;
    return created;
  }

  Stream<List<TripRecord>> watchTripsOrderedByStartDesc() {
    return _watch(_tripChanges.stream, getTripsOrderedByStartDesc);
  }

  Stream<int> watchVisitedCount() {
    return _watch(_visitChanges.stream, getVisitedCount);
  }

  Stream<List<CountryVisitRecord>> watchVisitedCountries() {
    return _watch(_visitChanges.stream, getVisitedCountriesOrderedByName);
  }

  Stream<List<WishlistItemRecord>> watchWishlist() {
    return _watch(_wishlistChanges.stream, getWishlistOrderedByCreatedAtDesc);
  }

  Future<List<TripRecord>> getTripsOrderedByStartDesc() async {
    final db = await _db;
    final rows = await db.query(tripsTable, orderBy: 'startDate DESC');
    return rows.map(TripRecord.fromMap).toList(growable: false);
  }

  Future<List<TripRecord>> getRecentTrips(int limit) async {
    final db = await _db;
    final rows = await db.query(
      tripsTable,
      orderBy: 'startDate DESC',
      limit: limit,
    );
    return rows.map(TripRecord.fromMap).toList(growable: false);
  }

  Future<TripRecord?> getTripById(int id) async {
    final db = await _db;
    final rows = await db.query(
      tripsTable,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return TripRecord.fromMap(rows.first);
  }

  Future<int> insertTrip(TripRecord trip) async {
    final db = await _db;

    final insertedId = await db.transaction((txn) async {
      final id = await txn.insert(tripsTable, trip.toMap());
      await txn.insert(
        countryVisitsTable,
        {
          'countryCode': trip.countryCode,
          'countryName': trip.countryName,
          'visitedAt': trip.startDate,
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
      return id;
    });

    _tripChanges.add(null);
    _visitChanges.add(null);
    return insertedId;
  }

  Future<void> updateTrip(TripRecord trip) async {
    final id = trip.id;
    if (id == null) {
      throw ArgumentError('Trip id is required for update.');
    }

    final db = await _db;
    await db.transaction((txn) async {
      await txn.update(
        tripsTable,
        trip.toMap(),
        where: 'id = ?',
        whereArgs: [id],
      );
      await txn.insert(
        countryVisitsTable,
        {
          'countryCode': trip.countryCode,
          'countryName': trip.countryName,
          'visitedAt': trip.startDate,
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    });

    _tripChanges.add(null);
    _visitChanges.add(null);
  }

  Future<void> deleteTrip(int id) async {
    final db = await _db;
    await db.delete(tripsTable, where: 'id = ?', whereArgs: [id]);
    _tripChanges.add(null);
  }

  Future<int> getVisitedCount() async {
    final db = await _db;
    final rows =
        await db.rawQuery('SELECT COUNT(*) AS count FROM $countryVisitsTable');
    final count = rows.first['count'];
    if (count is int) {
      return count;
    }
    if (count is num) {
      return count.toInt();
    }
    return 0;
  }

  Future<List<CountryVisitRecord>> getVisitedCountriesOrderedByName() async {
    final db = await _db;
    final rows = await db.query(
      countryVisitsTable,
      orderBy: 'countryName COLLATE NOCASE ASC',
    );
    return rows.map(CountryVisitRecord.fromMap).toList(growable: false);
  }

  Future<void> upsertVisitIfAbsent({
    required String countryCode,
    required String countryName,
    required int visitedAt,
  }) async {
    final db = await _db;
    await db.insert(
      countryVisitsTable,
      {
        'countryCode': countryCode,
        'countryName': countryName,
        'visitedAt': visitedAt,
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    _visitChanges.add(null);
  }

  Future<void> upsertVisit({
    required String countryCode,
    required String countryName,
    required int visitedAt,
  }) async {
    final db = await _db;
    await db.insert(
      countryVisitsTable,
      {
        'countryCode': countryCode.toUpperCase(),
        'countryName': countryName,
        'visitedAt': visitedAt,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    _visitChanges.add(null);
  }

  Future<void> deleteVisitByCountryCode(String countryCode) async {
    final db = await _db;
    await db.delete(
      countryVisitsTable,
      where: 'countryCode = ?',
      whereArgs: [countryCode.toUpperCase()],
    );
    _visitChanges.add(null);
  }

  Future<List<WishlistItemRecord>> getWishlistOrderedByCreatedAtDesc() async {
    final db = await _db;
    final rows = await db.query(wishlistTable, orderBy: 'createdAt DESC');
    return rows.map(WishlistItemRecord.fromMap).toList(growable: false);
  }

  Future<int> insertWishlistItem(WishlistItemRecord item) async {
    final db = await _db;
    final id = await db.insert(wishlistTable, item.toMap());
    _wishlistChanges.add(null);
    return id;
  }

  Future<void> updateWishlistItem(WishlistItemRecord item) async {
    final id = item.id;
    if (id == null) {
      throw ArgumentError('Wishlist item id is required for update.');
    }

    final db = await _db;
    await db.update(
      wishlistTable,
      item.toMap(),
      where: 'id = ?',
      whereArgs: [id],
    );
    _wishlistChanges.add(null);
  }

  Future<void> deleteWishlistItem(int id) async {
    final db = await _db;
    await db.delete(wishlistTable, where: 'id = ?', whereArgs: [id]);
    _wishlistChanges.add(null);
  }

  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }

    await _tripChanges.close();
    await _visitChanges.close();
    await _wishlistChanges.close();
  }

  Stream<T> _watch<T>(
    Stream<void> trigger,
    Future<T> Function() loader,
  ) async* {
    yield await loader();
    await for (final _ in trigger) {
      yield await loader();
    }
  }
}
