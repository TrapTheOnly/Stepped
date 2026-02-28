import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/db/app_db.dart';
import '../../data/repositories/trips_repository.dart';
import '../../data/repositories/wishlist_repository.dart';
import '../map/map_viewmodel.dart';
import 'stats_calculations.dart';
import 'widgets/stat_metric.dart';

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

    final totalDays = totalTripDays(trips);
    final averageTripDays =
        trips.isEmpty ? 0 : (totalDays / trips.length).toStringAsFixed(1);
    final uniqueCities = uniqueCitiesCount(trips);
    final topCountryEntries = topCountries(trips);
    final yearlyTripEntries = yearlyTrips(trips);

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
                        child: StatMetric(
                          label: 'Countries',
                          value: '${dashboard.visitedCount}',
                        ),
                      ),
                      Expanded(
                        child: StatMetric(
                          label: 'Trips',
                          value: '${dashboard.totalTrips}',
                        ),
                      ),
                      Expanded(
                        child: StatMetric(
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
                        child: StatMetric(
                          label: 'Travel days',
                          value: '$totalDays',
                        ),
                      ),
                      Expanded(
                        child: StatMetric(
                          label: 'Avg trip',
                          value: '$averageTripDays d',
                        ),
                      ),
                      Expanded(
                        child: StatMetric(
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
                  if (topCountryEntries.isEmpty)
                    Text(
                      'No trip destinations yet.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    )
                  else
                    ...topCountryEntries.map(
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
                  if (yearlyTripEntries.isEmpty)
                    Text(
                      'No year trend available yet.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    )
                  else
                    ...yearlyTripEntries.map(
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

}
