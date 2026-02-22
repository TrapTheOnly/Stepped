import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../db/app_db.dart';

final wishlistRepositoryProvider = Provider<WishlistRepository>((ref) {
  return WishlistRepository(ref.watch(databaseProvider));
});

final wishlistStreamProvider = StreamProvider<List<WishlistItemRecord>>((ref) {
  return ref.watch(wishlistRepositoryProvider).watchWishlist();
});

class WishlistRepository {
  const WishlistRepository(this._database);

  final AppDatabase _database;

  Stream<List<WishlistItemRecord>> watchWishlist() {
    return _database.watchWishlist();
  }

  Future<int> addWishlistItem(WishlistItemRecord item) {
    return _database.insertWishlistItem(item);
  }

  Future<void> updateWishlistItem(WishlistItemRecord item) {
    return _database.updateWishlistItem(item);
  }

  Future<void> deleteWishlistItem(int id) {
    return _database.deleteWishlistItem(id);
  }
}
