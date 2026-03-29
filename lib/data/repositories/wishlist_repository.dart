import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../db/app_db.dart';

final wishlistRepositoryProvider = Provider<WishlistRepository>((ref) {
  return WishlistRepository(ref.watch(databaseProvider));
});

final wishlistStreamProvider = StreamProvider<List<WishlistItemRecord>>((ref) {
  return ref.watch(wishlistRepositoryProvider).watchWishlist();
});

final wishlistItemProvider =
    FutureProvider.family<WishlistItemRecord?, int>((ref, id) {
  return ref.watch(wishlistRepositoryProvider).getWishlistItemById(id);
});

class WishlistRepository {
  const WishlistRepository(this._database);

  final AppDatabase _database;

  Future<List<WishlistItemRecord>> getWishlistItems() {
    return _database.getWishlistOrderedByCreatedAtDesc();
  }

  Stream<List<WishlistItemRecord>> watchWishlist() {
    return _database.watchWishlist();
  }

  Future<WishlistItemRecord?> getWishlistItemById(int id) {
    return _database.getWishlistItemById(id);
  }

  Future<int> addWishlistItem(WishlistItemRecord item) {
    return _database.insertWishlistItem(item);
  }

  Future<void> updateWishlistItem(WishlistItemRecord item) {
    return _database.updateWishlistItem(item);
  }

  Future<void> replaceWishlistItems(List<WishlistItemRecord> items) {
    return _database.replaceWishlistItems(items);
  }

  Future<void> deleteWishlistItem(int id) {
    return _database.deleteWishlistItem(id);
  }

  Future<void> setPinnedState({
    required int id,
    required bool isPinned,
  }) {
    return _database.setWishlistPinnedState(id: id, isPinned: isPinned);
  }
}
