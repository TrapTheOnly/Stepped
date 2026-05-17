import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'tables.dart';
import 'app_db_models.dart';
export 'app_db_models.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  final database = AppDatabase();
  ref.onDispose(database.close);
  return database;
});

class AppDatabase {
  static const _databaseName = 'stepped.db';

  static const _databaseVersion = 5;

  Database? _database;
  bool _didDeleteLegacyOnDiskDatabase = false;

  final StreamController<void> _tripChanges =
      StreamController<void>.broadcast(sync: true);

  final StreamController<void> _visitChanges =
      StreamController<void>.broadcast(sync: true);

  final StreamController<void> _wishlistChanges =
      StreamController<void>.broadcast(sync: true);

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

  Future<void> replaceTrips(List<TripRecord> trips) async {
    final db = await _db;
    await db.transaction((txn) async {
      await txn.delete(tripsTable);
      for (final trip in trips) {
        await txn.insert(tripsTable, trip.toMap());
      }
    });

    _tripChanges.add(null);
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

  Future<void> replaceVisitedCountries(List<CountryVisitRecord> visits) async {
    final db = await _db;
    await db.transaction((txn) async {
      await txn.delete(countryVisitsTable);
      for (final visit in visits) {
        await txn.insert(countryVisitsTable, visit.toMap());
      }
    });
    _visitChanges.add(null);
  }

  Future<List<WishlistItemRecord>> getWishlistOrderedByCreatedAtDesc() async {
    final db = await _db;
    final rows = await db.query(
      wishlistTable,
      orderBy: 'isPinned DESC, createdAt DESC',
    );
    return rows.map(WishlistItemRecord.fromMap).toList(growable: false);
  }

  Future<WishlistItemRecord?> getWishlistItemById(int id) async {
    final db = await _db;
    final rows = await db.query(
      wishlistTable,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return WishlistItemRecord.fromMap(rows.first);
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

  Future<void> setWishlistPinnedState({
    required int id,
    required bool isPinned,
  }) async {
    final db = await _db;
    await db.transaction((txn) async {
      if (isPinned) {
        await txn.update(
          wishlistTable,
          <String, Object?>{'isPinned': 0},
        );
      }
      await txn.update(
        wishlistTable,
        <String, Object?>{'isPinned': isPinned ? 1 : 0},
        where: 'id = ?',
        whereArgs: <Object?>[id],
      );
    });
    _wishlistChanges.add(null);
  }

  Future<void> replaceWishlistItems(List<WishlistItemRecord> items) async {
    final db = await _db;
    await db.transaction((txn) async {
      await txn.delete(wishlistTable);
      for (final item in items) {
        await txn.insert(wishlistTable, item.toMap());
      }
    });
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

  Future<void> clearSocialData() async {
    final db = _database;
    if (db == null) {
      return;
    }

    await db.transaction((txn) async {
      await txn.delete(tripsTable);
      await txn.delete(countryVisitsTable);
      await txn.delete(wishlistTable);
    });

    _tripChanges.add(null);
    _visitChanges.add(null);
    _wishlistChanges.add(null);
  }
}

extension _AppDatabaseInternalMethods on AppDatabase {
  Future<Database> get _db async {
    final existing = _database;
    if (existing != null) {
      return existing;
    }

    await _deleteLegacyOnDiskDatabaseIfPresent();
    final created = await openDatabase(
      inMemoryDatabasePath,
      version: AppDatabase._databaseVersion,
      onCreate: (db, _) async {
        await db.execute(createCountryVisitsTable);
        await db.execute(createTripsTable);
        await db.execute(createWishlistTable);
        await db.execute(createTripsStartDateIndex);
        await db.execute(createTripsRemoteIdIndex);
        await db.execute(createWishlistCreatedAtIndex);
        await db.execute(createWishlistRemoteIdIndex);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 1) {
          await db.execute(createCountryVisitsTable);
          await db.execute(createTripsTable);
          await db.execute(createWishlistTable);
          await db.execute(createTripsStartDateIndex);
          await db.execute(createTripsRemoteIdIndex);
          await db.execute(createWishlistCreatedAtIndex);
          await db.execute(createWishlistRemoteIdIndex);
        }
        if (oldVersion < 2) {
          await _addColumnIfMissing(
            db,
            'ALTER TABLE $wishlistTable ADD COLUMN countryCode TEXT',
          );
          await _addColumnIfMissing(
            db,
            'ALTER TABLE $wishlistTable ADD COLUMN plannedStartDate INTEGER',
          );
          await _addColumnIfMissing(
            db,
            'ALTER TABLE $wishlistTable ADD COLUMN plannedEndDate INTEGER',
          );
          await _addColumnIfMissing(
            db,
            'ALTER TABLE $wishlistTable ADD COLUMN plannedCities TEXT',
          );
          await _addColumnIfMissing(
            db,
            'ALTER TABLE $wishlistTable ADD COLUMN aiPlan TEXT',
          );
        }
        if (oldVersion < 3) {
          await _addColumnIfMissing(
            db,
            'ALTER TABLE $wishlistTable ADD COLUMN isPinned INTEGER NOT NULL DEFAULT 0',
          );
        }
        if (oldVersion < 4) {
          await _addColumnIfMissing(
            db,
            'ALTER TABLE $tripsTable ADD COLUMN sourceWishlistItemId INTEGER',
          );
          await _addColumnIfMissing(
            db,
            'ALTER TABLE $tripsTable ADD COLUMN cityDataJson TEXT',
          );
        }
        if (oldVersion < 5) {
          await _addColumnIfMissing(
            db,
            'ALTER TABLE $tripsTable ADD COLUMN remoteId TEXT',
          );
          await _addColumnIfMissing(
            db,
            'ALTER TABLE $wishlistTable ADD COLUMN remoteId TEXT',
          );
          await _createIndexIfMissing(db, createTripsRemoteIdIndex);
          await _createIndexIfMissing(db, createWishlistRemoteIdIndex);
        }
      },
    );

    _database = created;
    return created;
  }

  Future<void> _deleteLegacyOnDiskDatabaseIfPresent() async {
    if (_didDeleteLegacyOnDiskDatabase) {
      return;
    }
    _didDeleteLegacyOnDiskDatabase = true;

    try {
      final legacyPath =
          p.join(await getDatabasesPath(), AppDatabase._databaseName);
      if (await databaseExists(legacyPath)) {
        await deleteDatabase(legacyPath);
      }
    } on FileSystemException {
      // Ignore cleanup failures; in-memory storage is already the source used.
    } on DatabaseException {
      // Ignore cleanup failures; in-memory storage is already the source used.
    }
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

  Future<void> _addColumnIfMissing(Database db, String statement) async {
    try {
      await db.execute(statement);
    } on DatabaseException {
      // Ignore duplicate-column failures for defensive migrations.
    }
  }

  Future<void> _createIndexIfMissing(Database db, String statement) async {
    try {
      await db.execute(statement);
    } on DatabaseException {
      // Ignore duplicate-index failures for defensive migrations.
    }
  }
}
