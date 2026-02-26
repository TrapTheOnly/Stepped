import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/db/app_db.dart';
import '../../data/repositories/trips_repository.dart';
import '../../data/repositories/visits_repository.dart';
import '../../data/repositories/wishlist_repository.dart';
import '../map/map_viewmodel.dart';
import '../settings/app_preferences.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visitedAsync = ref.watch(visitedCountProvider);
    final tripsAsync = ref.watch(tripsStreamProvider);
    final wishlistAsync = ref.watch(wishlistStreamProvider);
    final preferencesAsync = ref.watch(appPreferencesProvider);

    final visited = visitedAsync.valueOrNull ?? 0;
    final trips = tripsAsync.valueOrNull ?? const <TripRecord>[];
    final wishlistItems =
        wishlistAsync.valueOrNull ?? const <WishlistItemRecord>[];
    final preferences = preferencesAsync.valueOrNull ?? AppPreferences.defaults;
    final latestTrip = trips.isEmpty ? null : trips.first;
    final coverage = totalCountriesInWorld == 0
        ? 0.0
        : (visited / totalCountriesInWorld).clamp(0.0, 1.0);

    final hasError = visitedAsync.hasError ||
        tripsAsync.hasError ||
        wishlistAsync.hasError ||
        preferencesAsync.hasError;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: <Widget>[
          IconButton(
            onPressed: () => context.push('/profile/settings'),
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
        children: <Widget>[
          _ProfileHeaderCard(
            displayName: preferences.displayName,
            homeBase: preferences.homeBase,
          ),
          const SizedBox(height: 14),
          Row(
            children: <Widget>[
              Expanded(
                child: _StatCard(
                  label: 'Countries',
                  value: visitedAsync.isLoading ? '...' : '$visited',
                  icon: Icons.public,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatCard(
                  label: 'Trips',
                  value: tripsAsync.isLoading ? '...' : '${trips.length}',
                  icon: Icons.flight_takeoff,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatCard(
                  label: 'Wishlist',
                  value: wishlistAsync.isLoading
                      ? '...'
                      : '${wishlistItems.length}',
                  icon: Icons.favorite,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'World progress',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 10),
                  LinearProgressIndicator(
                    value: coverage,
                    minHeight: 9,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '$visited of $totalCountriesInWorld countries visited (${(coverage * 100).toStringAsFixed(1)}%)',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Latest activity',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  if (latestTrip == null)
                    Text(
                      'No trips yet. Add your first trip to start building your journey.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    )
                  else
                    Text(
                      'Last trip: ${latestTrip.countryName}',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Card(
            child: Column(
              children: <Widget>[
                ListTile(
                  leading: const Icon(Icons.settings_outlined),
                  title: const Text('Settings'),
                  subtitle: const Text('Appearance and behavior'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/profile/settings'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.favorite_outline),
                  title: const Text('Wishlist'),
                  subtitle: const Text('Ideas for upcoming trips'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.go('/wishlist'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.flight_takeoff_outlined),
                  title: const Text('Trips'),
                  subtitle: const Text('Manage past and future trips'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.go('/trips'),
                ),
              ],
            ),
          ),
          if (hasError) ...<Widget>[
            const SizedBox(height: 14),
            Card(
              color: Theme.of(context).colorScheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Text(
                  'Some profile data failed to load. Pull to refresh or reopen the page.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onErrorContainer,
                      ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ProfileHeaderCard extends StatelessWidget {
  const _ProfileHeaderCard({
    required this.displayName,
    required this.homeBase,
  });

  final String displayName;
  final String homeBase;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final trimmedName = displayName.trim();
    final initials = displayName.trim().isEmpty
        ? 'T'
        : trimmedName.substring(0, 1).toUpperCase();

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
        child: Row(
          children: <Widget>[
            CircleAvatar(
              radius: 26,
              backgroundColor: colorScheme.primaryContainer,
              child: Text(
                initials,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    displayName,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    homeBase.isEmpty ? 'Home base not set' : homeBase,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(icon, size: 18),
            const SizedBox(height: 10),
            Text(
              value,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
