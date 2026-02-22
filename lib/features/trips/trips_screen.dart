import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/db/app_db.dart';
import '../../data/repositories/trips_repository.dart';
import '../../domain/models/trip_ui.dart';

class TripsScreen extends ConsumerWidget {
  const TripsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tripsAsync = ref.watch(tripsStreamProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Trips')),
      body: tripsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Failed to load trips: $error')),
        data: (trips) {
          if (trips.isEmpty) {
            return const Center(child: Text('No trips yet.'));
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
            itemCount: trips.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final trip = trips[index];
              final tripUi = TripUi.fromRecord(trip);

              return Semantics(
                label: 'Trip to ${tripUi.countryName}',
                child: Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(12),
                    leading: _TripListImage(uri: trip.coverImageUri),
                    title: Text(tripUi.countryName),
                    subtitle: Text('${tripUi.dateRange}\n${tripUi.cities}'),
                    isThreeLine: true,
                    trailing: _TripActions(
                      onEdit: () => context.push('/trips/edit/${tripUi.id}'),
                      onDelete: () => _confirmDelete(context, ref, trip),
                    ),
                    onTap: () => context.push('/trips/edit/${tripUi.id}'),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/trips/add'),
        icon: const Icon(Icons.add),
        label: const Text('Add trip'),
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    TripRecord trip,
  ) async {
    final shouldDelete = await showDialog<bool>(
          context: context,
          builder: (dialogContext) {
            return AlertDialog(
              title: const Text('Delete trip?'),
              content: Text('Remove ${trip.countryName} from your trips list.'),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: const Text('Delete'),
                ),
              ],
            );
          },
        ) ??
        false;

    if (!shouldDelete) {
      return;
    }

    await ref.read(tripsRepositoryProvider).deleteTrip(trip.id!);
  }
}

class _TripActions extends StatelessWidget {
  const _TripActions({
    required this.onEdit,
    required this.onDelete,
  });

  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 80,
      child: Row(
        children: <Widget>[
          IconButton(
            onPressed: onEdit,
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit',
          ),
          IconButton(
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Delete',
          ),
        ],
      ),
    );
  }
}

class _TripListImage extends StatelessWidget {
  const _TripListImage({required this.uri});

  final String? uri;

  @override
  Widget build(BuildContext context) {
    final value = uri?.trim();

    Widget child;
    if (value == null || value.isEmpty) {
      child = const Icon(Icons.map_outlined);
    } else if (value.startsWith('http://') || value.startsWith('https://')) {
      child = CachedNetworkImage(
        imageUrl: value,
        fit: BoxFit.cover,
        errorWidget: (_, __, ___) => const Icon(Icons.map_outlined),
      );
    } else {
      final path = value.startsWith('file://') ? value.replaceFirst('file://', '') : value;
      final file = File(path);
      child = file.existsSync()
          ? Image.file(file, fit: BoxFit.cover)
          : const Icon(Icons.map_outlined);
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox.square(
        dimension: 60,
        child: ColoredBox(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: child,
        ),
      ),
    );
  }
}
