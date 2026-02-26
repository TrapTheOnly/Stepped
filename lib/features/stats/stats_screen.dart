import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/db/app_db.dart';
import '../../data/repositories/trips_repository.dart';
import '../../data/repositories/wishlist_repository.dart';
import '../map/map_viewmodel.dart';

class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardAsync = ref.watch(mapDashboardProvider);
    final tripsAsync = ref.watch(tripsStreamProvider);
    final wishlistAsync = ref.watch(wishlistStreamProvider);

    final hasError = dashboardAsync.hasError ||
        tripsAsync.hasError ||
        wishlistAsync.hasError;
    final error =
        dashboardAsync.error ?? tripsAsync.error ?? wishlistAsync.error;

    if (dashboardAsync.isLoading ||
        tripsAsync.isLoading ||
        wishlistAsync.isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (hasError || dashboardAsync.value == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('My Stats')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text('Unable to load stats: $error'),
          ),
        ),
      );
    }

    final dashboard = dashboardAsync.value!;
    final trips = tripsAsync.valueOrNull ?? const <TripRecord>[];
    final wishlistItems =
        wishlistAsync.valueOrNull ?? const <WishlistItemRecord>[];

    final totalTripDays = _totalTripDays(trips);
    final averageTripDays =
        trips.isEmpty ? 0 : (totalTripDays / trips.length).toStringAsFixed(1);
    final uniqueCities = _uniqueCitiesCount(trips);
    final topCountries = _topCountries(trips);
    final yearlyTrips = _yearlyTrips(trips);

    return Scaffold(
      appBar: AppBar(title: const Text('My Stats')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: <Widget>[
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Travel snapshot',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: _StatMetric(
                          label: 'Countries',
                          value: '${dashboard.visitedCount}',
                        ),
                      ),
                      Expanded(
                        child: _StatMetric(
                          label: 'Trips',
                          value: '${dashboard.totalTrips}',
                        ),
                      ),
                      Expanded(
                        child: _StatMetric(
                          label: 'Wishlist',
                          value: '${wishlistItems.length}',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Trip depth',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: _StatMetric(
                          label: 'Travel days',
                          value: '$totalTripDays',
                        ),
                      ),
                      Expanded(
                        child: _StatMetric(
                          label: 'Avg trip',
                          value: '$averageTripDays d',
                        ),
                      ),
                      Expanded(
                        child: _StatMetric(
                          label: 'Unique cities',
                          value: '$uniqueCities',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Continent coverage',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 10),
                  ...dashboard.continentProgress.map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              Expanded(child: Text(item.continent)),
                              Text('${item.visitedCount}/${item.totalCount}'),
                            ],
                          ),
                          const SizedBox(height: 6),
                          LinearProgressIndicator(
                            value: item.progress,
                            minHeight: 8,
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Top destinations',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 10),
                  if (topCountries.isEmpty)
                    Text(
                      'No trip destinations yet.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    )
                  else
                    ...topCountries.map(
                      (entry) => ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(entry.key),
                        trailing: Text('${entry.value} trips'),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Trips by year',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 10),
                  if (yearlyTrips.isEmpty)
                    Text(
                      'No year trend available yet.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    )
                  else
                    ...yearlyTrips.map(
                      (entry) => ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text('${entry.key}'),
                        trailing: Text('${entry.value}'),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  int _totalTripDays(List<TripRecord> trips) {
    return trips.fold<int>(0, (sum, trip) {
      final start = DateTime.fromMillisecondsSinceEpoch(trip.startDate);
      final end = DateTime.fromMillisecondsSinceEpoch(trip.endDate);
      final days = end.difference(start).inDays + 1;
      return sum + (days < 1 ? 1 : days);
    });
  }

  int _uniqueCitiesCount(List<TripRecord> trips) {
    final cities = <String>{};
    for (final trip in trips) {
      final parts = trip.cities.split(',');
      for (final part in parts) {
        final city = part.trim().toLowerCase();
        if (city.isNotEmpty) {
          cities.add(city);
        }
      }
    }
    return cities.length;
  }

  List<MapEntry<String, int>> _topCountries(List<TripRecord> trips) {
    final counts = <String, int>{};
    for (final trip in trips) {
      counts[trip.countryName] = (counts[trip.countryName] ?? 0) + 1;
    }
    final sorted = counts.entries.toList(growable: false)
      ..sort((a, b) => b.value.compareTo(a.value));
    if (sorted.length <= 5) {
      return sorted;
    }
    return sorted.take(5).toList(growable: false);
  }

  List<MapEntry<int, int>> _yearlyTrips(List<TripRecord> trips) {
    final counts = <int, int>{};
    for (final trip in trips) {
      final year = DateTime.fromMillisecondsSinceEpoch(trip.startDate).year;
      counts[year] = (counts[year] ?? 0) + 1;
    }
    final sorted = counts.entries.toList(growable: false)
      ..sort((a, b) => b.key.compareTo(a.key));
    return sorted;
  }
}

class _StatMetric extends StatelessWidget {
  const _StatMetric({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        children: <Widget>[
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
