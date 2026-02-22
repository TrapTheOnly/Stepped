import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/db/app_db.dart';
import '../../data/repositories/wishlist_repository.dart';

class WishlistScreen extends ConsumerWidget {
  const WishlistScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wishlistAsync = ref.watch(wishlistStreamProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Wishlist')),
      body: wishlistAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Failed to load wishlist: $error')),
        data: (items) {
          if (items.isEmpty) {
            return const Center(child: Text('No wishlist items yet.'));
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final item = items[index];
              return Semantics(
                label: 'Wishlist item ${item.title}',
                child: Card(
                  child: ListTile(
                    title: Text(item.title),
                    subtitle: item.countryName == null || item.countryName!.isEmpty
                        ? null
                        : Text(item.countryName!),
                    trailing: SizedBox(
                      width: 80,
                      child: Row(
                        children: <Widget>[
                          IconButton(
                            onPressed: () => _showWishlistDialog(
                              context,
                              ref,
                              existingItem: item,
                            ),
                            tooltip: 'Edit',
                            icon: const Icon(Icons.edit_outlined),
                          ),
                          IconButton(
                            onPressed: () => _deleteItem(ref, item.id!),
                            tooltip: 'Delete',
                            icon: const Icon(Icons.delete_outline),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showWishlistDialog(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Add item'),
      ),
    );
  }

  Future<void> _showWishlistDialog(
    BuildContext context,
    WidgetRef ref, {
    WishlistItemRecord? existingItem,
  }) async {
    final titleController = TextEditingController(text: existingItem?.title ?? '');
    final countryController = TextEditingController(text: existingItem?.countryName ?? '');

    final submitted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(existingItem == null ? 'Add Wishlist Item' : 'Edit Wishlist Item'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TextField(
                controller: titleController,
                decoration: const InputDecoration(labelText: 'Title'),
                autofocus: true,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: countryController,
                decoration: const InputDecoration(labelText: 'Country (optional)'),
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (submitted != true) {
      titleController.dispose();
      countryController.dispose();
      return;
    }

    final title = titleController.text.trim();
    final country = countryController.text.trim();
    titleController.dispose();
    countryController.dispose();

    if (title.isEmpty) {
      return;
    }

    final repository = ref.read(wishlistRepositoryProvider);
    final timestamp = DateTime.now().millisecondsSinceEpoch;

    if (existingItem == null) {
      await repository.addWishlistItem(
        WishlistItemRecord(
          title: title,
          countryName: country.isEmpty ? null : country,
          createdAt: timestamp,
        ),
      );
    } else {
      await repository.updateWishlistItem(
        existingItem.copyWith(
          title: title,
          countryName: country.isEmpty ? null : country,
        ),
      );
    }
  }

  Future<void> _deleteItem(WidgetRef ref, int id) {
    return ref.read(wishlistRepositoryProvider).deleteWishlistItem(id);
  }
}
