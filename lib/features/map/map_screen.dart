import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../widgets/progress_row.dart';
import '../../widgets/trip_card.dart';
import 'globe/globe_widget.dart';
import 'map_viewmodel.dart';

class MapScreen extends ConsumerWidget {
  const MapScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<AsyncValue<void>>(mapVisitToggleControllerProvider,
        (previous, next) {
      if (next.hasError) {
        final messenger = ScaffoldMessenger.maybeOf(context);
        if (messenger == null) {
          return;
        }

        messenger.showSnackBar(
          SnackBar(
              content: Text('Failed to update visited country: ${next.error}')),
        );
      }
    });

    final dashboardAsync = ref.watch(mapDashboardProvider);

    Widget bodySliver;
    if (dashboardAsync.hasError) {
      bodySliver = SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
            child: Text('Unable to load dashboard: ${dashboardAsync.error}')),
      );
    } else if (dashboardAsync.isLoading || dashboardAsync.value == null) {
      bodySliver = const SliverFillRemaining(
        hasScrollBody: false,
        child: Center(child: CircularProgressIndicator()),
      );
    } else {
      final dashboard = dashboardAsync.value!;
      bodySliver = SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        sliver: SliverList(
          delegate: SliverChildListDelegate(
            <Widget>[
              _GlobeCard(
                visitedCountryCodes: dashboard.visitedCountryCodes,
                onSetVisited: (countryCode, countryName, visited) {
                  return ref
                      .read(mapVisitToggleControllerProvider.notifier)
                      .setVisited(
                        countryCode: countryCode,
                        countryName: countryName,
                        visited: visited,
                      );
                },
              ),
              const SizedBox(height: 16),
              Center(
                child: Chip(
                  label: Text(
                    'Countries Visited: ${dashboard.visitedCount} / $totalCountriesInWorld',
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ProgressRow(
                label: 'Continents',
                value: dashboard.continentsVisited,
                total: totalContinentsInWorld,
              ),
              ProgressRow(
                label: 'World',
                value: dashboard.worldVisited,
                total: totalCountriesInWorld,
              ),
              const SizedBox(height: 8),
              _ActionRow(
                onAddTrip: () => context.push('/trips/add'),
                onStats: () => context.push('/stats'),
                onWishlist: () => context.go('/wishlist'),
              ),
              const SizedBox(height: 24),
              Text(
                'Recent Trips',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 236,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: dashboard.recentTrips.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    final trip = dashboard.recentTrips[index];
                    return TripCard(
                      trip: trip,
                      onTap: () => context.push('/trips/edit/${trip.id}'),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      );
    }

    return CustomScrollView(
      slivers: <Widget>[
        SliverAppBar.large(
          title: const Text('Stepped'),
          leading: IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () {},
            tooltip: 'Menu',
          ),
          actions: <Widget>[
            IconButton(
              icon: const Icon(Icons.search),
              tooltip: 'Search',
              onPressed: () => context.push('/search'),
            ),
            IconButton(
              icon: const Icon(Icons.settings),
              tooltip: 'Settings',
              onPressed: () => context.push('/profile/settings'),
            ),
          ],
        ),
        bodySliver,
      ],
    );
  }
}

class _GlobeCard extends StatelessWidget {
  const _GlobeCard({
    required this.visitedCountryCodes,
    required this.onSetVisited,
  });

  final List<String> visitedCountryCodes;
  final Future<void> Function(
      String countryCode, String countryName, bool visited) onSetVisited;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          height: 320,
          child: GlobeWidget(
            visitedCountryCodes: visitedCountryCodes,
            onSetVisited: onSetVisited,
          ),
        ),
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.onAddTrip,
    required this.onStats,
    required this.onWishlist,
  });

  final VoidCallback onAddTrip;
  final VoidCallback onStats;
  final VoidCallback onWishlist;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Semantics(
            button: true,
            label: 'Add trip',
            child: FilledButton(
              onPressed: onAddTrip,
              child: const Text('Add trip'),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Semantics(
            button: true,
            label: 'My stats',
            child: FilledButton.tonal(
              onPressed: onStats,
              child: const Text('My stats'),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Semantics(
            button: true,
            label: 'Wishlist',
            child: FilledButton.tonal(
              onPressed: onWishlist,
              child: const Text('Wishlist'),
            ),
          ),
        ),
      ],
    );
  }
}
