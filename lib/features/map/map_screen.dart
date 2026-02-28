import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/models/trip_ui.dart';
import '../../widgets/trip_card.dart';
import 'globe/globe_widget.dart';
import 'map_viewmodel.dart';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  bool _isGlobeInteracting = false;

  void _handleGlobeInteractionChanged(bool interacting) {
    if (_isGlobeInteracting == interacting || !mounted) {
      return;
    }
    setState(() {
      _isGlobeInteracting = interacting;
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<void>>(mapVisitToggleControllerProvider,
        (previous, next) {
      if (next.hasError) {
        final messenger = ScaffoldMessenger.maybeOf(context);
        if (messenger == null) {
          return;
        }
        messenger.showSnackBar(
          SnackBar(
            content: Text('Failed to update visited country: ${next.error}'),
          ),
        );
      }
    });

    final dashboardAsync = ref.watch(mapDashboardProvider);
    final focusRequest = ref.watch(globeFocusRequestProvider);

    final random = Random();
    final visitedCountryCodes = dashboardAsync.valueOrNull?.visitedCountryCodes;
    void onFocusRandomVisited() {
      final visited = visitedCountryCodes ?? const <String>[];
      if (visited.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text('No visited countries yet. Mark one on the globe first.'),
          ),
        );
        return;
      }

      final randomCode = visited[random.nextInt(visited.length)];
      ref.read(globeFocusRequestProvider.notifier).state = GlobeFocusRequest(
        countryCode: randomCode,
        token: DateTime.now().microsecondsSinceEpoch,
      );
    }

    Widget bodySliver;
    if (dashboardAsync.hasError) {
      bodySliver = SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text('Unable to load dashboard: ${dashboardAsync.error}'),
          ),
        ),
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
                focusCountryCode: focusRequest?.countryCode,
                focusRequestToken: focusRequest?.token,
                onInteractionChanged: _handleGlobeInteractionChanged,
                onFocusRequestConsumed: (countryCode, token) {
                  final activeRequest = ref.read(globeFocusRequestProvider);
                  if (activeRequest == null) {
                    return;
                  }

                  final matchesCountry =
                      activeRequest.countryCode.toUpperCase() ==
                          countryCode.toUpperCase();
                  final matchesToken =
                      token == null || activeRequest.token == token;
                  if (!matchesCountry || !matchesToken) {
                    return;
                  }

                  ref.read(globeFocusRequestProvider.notifier).state = null;
                },
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
              const SizedBox(height: 14),
              _JourneyOverviewCard(dashboard: dashboard),
              const SizedBox(height: 12),
              _ContinentCoverageCard(progress: dashboard.continentProgress),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => context.push('/trips/add'),
                  icon: const Icon(Icons.add),
                  label: const Text('Add a new trip'),
                ),
              ),
              const SizedBox(height: 22),
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      'Recent Trips',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  TextButton(
                    onPressed: () => context.go('/trips'),
                    child: const Text('See all'),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (dashboard.recentTrips.isEmpty)
                const _NoTripsCard()
              else
                _RecentTripsRail(trips: dashboard.recentTrips),
            ],
          ),
        ),
      );
    }

    return CustomScrollView(
      physics: _isGlobeInteracting
          ? const NeverScrollableScrollPhysics()
          : const ClampingScrollPhysics(),
      slivers: <Widget>[
        SliverAppBar.large(
          title: const Text('Stepped'),
          leading: IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => _showMapQuickActions(
              context,
              onAddTrip: () => context.push('/trips/add'),
              onOpenStats: () => context.push('/stats'),
              onFocusRandomVisited: onFocusRandomVisited,
              onShowMapTips: () => _showMapTips(context),
            ),
            tooltip: 'Menu',
          ),
          actions: <Widget>[
            IconButton(
              icon: const Icon(Icons.settings),
              tooltip: 'Settings',
              onPressed: () => context.push('/profile/settings'),
            ),
          ],
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
            child: SearchBar(
              hintText: 'Search countries on the globe',
              leading: const Icon(Icons.search),
              trailing: const <Widget>[
                Icon(Icons.keyboard_arrow_right),
              ],
              onTap: () => context.push('/search'),
            ),
          ),
        ),
        bodySliver,
      ],
    );
  }
}

class _GlobeCard extends StatelessWidget {
  const _GlobeCard({
    required this.visitedCountryCodes,
    required this.focusCountryCode,
    required this.focusRequestToken,
    required this.onInteractionChanged,
    required this.onFocusRequestConsumed,
    required this.onSetVisited,
  });

  final List<String> visitedCountryCodes;
  final String? focusCountryCode;
  final int? focusRequestToken;
  final ValueChanged<bool> onInteractionChanged;
  final void Function(String countryCode, int? token) onFocusRequestConsumed;
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
            focusCountryCode: focusCountryCode,
            focusRequestToken: focusRequestToken,
            onInteractionChanged: onInteractionChanged,
            onFocusRequestConsumed: onFocusRequestConsumed,
          ),
        ),
      ),
    );
  }
}


class _JourneyOverviewCard extends StatelessWidget {
  const _JourneyOverviewCard({required this.dashboard});

  final MapDashboardState dashboard;

  @override
  Widget build(BuildContext context) {
    final progress = totalCountriesInWorld == 0
        ? 0.0
        : (dashboard.visitedCount / totalCountriesInWorld).clamp(0.0, 1.0);
    final progressText = '${(progress * 100).toStringAsFixed(1)}% explored';

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Journey progress',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 10),
            Row(
              children: <Widget>[
                _MetricChip(
                  label: 'Visited',
                  value: '${dashboard.visitedCount}/$totalCountriesInWorld',
                ),
                const SizedBox(width: 8),
                _MetricChip(
                  label: 'Continents',
                  value:
                      '${dashboard.continentsVisited}/$totalContinentsInWorld',
                ),
                const SizedBox(width: 8),
                _MetricChip(
                  label: 'Trips',
                  value: '${dashboard.totalTrips}',
                ),
              ],
            ),
            const SizedBox(height: 14),
            LinearProgressIndicator(
              value: progress,
              minHeight: 10,
              borderRadius: BorderRadius.circular(14),
            ),
            const SizedBox(height: 8),
            Text(
              progressText,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: <Widget>[
            Text(
              value,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _ContinentCoverageCard extends StatelessWidget {
  const _ContinentCoverageCard({required this.progress});

  final List<ContinentProgress> progress;

  @override
  Widget build(BuildContext context) {
    return Card(
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
            ...progress.map(
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
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: item.progress,
                        minHeight: 7,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentTripsRail extends StatelessWidget {
  const _RecentTripsRail({required this.trips});

  final List<TripUi> trips;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 236,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: trips.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final trip = trips[index];
          return TripCard(
            trip: trip,
            onTap: () => context.push('/trips/edit/${trip.id}'),
          );
        },
      ),
    );
  }
}

class _NoTripsCard extends StatelessWidget {
  const _NoTripsCard();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
        child: Row(
          children: <Widget>[
            CircleAvatar(
              radius: 22,
              backgroundColor: colorScheme.primaryContainer,
              child: Icon(Icons.flight_takeoff,
                  color: colorScheme.onPrimaryContainer),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'No recent trips yet. Add your first trip to start your timeline.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _showMapQuickActions(
  BuildContext context, {
  required VoidCallback onAddTrip,
  required VoidCallback onOpenStats,
  required VoidCallback onFocusRandomVisited,
  required VoidCallback onShowMapTips,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ListTile(
              leading: const Icon(Icons.add_circle_outline),
              title: const Text('Add trip'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                onAddTrip();
              },
            ),
            ListTile(
              leading: const Icon(Icons.shuffle),
              title: const Text('Focus random visited country'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                onFocusRandomVisited();
              },
            ),
            ListTile(
              leading: const Icon(Icons.insights_outlined),
              title: const Text('Open travel stats'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                onOpenStats();
              },
            ),
            ListTile(
              leading: const Icon(Icons.help_outline),
              title: const Text('Map tips'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                onShowMapTips();
              },
            ),
          ],
        ),
      );
    },
  );
}


Future<void> _showMapTips(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: const Text('Map tips'),
        content: const Text(
          'Double-tap a country to focus it. Double-tap the same country again to unselect. Use pinch or mouse wheel to zoom.',
        ),
        actions: <Widget>[
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Got it'),
          ),
        ],
      );
    },
  );
}
