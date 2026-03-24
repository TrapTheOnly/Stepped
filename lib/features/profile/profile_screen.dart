import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/db/app_db.dart';
import '../../data/repositories/trips_repository.dart';
import '../../data/repositories/visits_repository.dart';
import '../../data/repositories/wishlist_repository.dart';
import '../auth/auth_controller.dart';
import '../map/map_viewmodel.dart';
import '../settings/app_preferences.dart';
import 'widgets/profile_summary_widgets.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visitedAsync = ref.watch(visitedCountProvider);
    final tripsAsync = ref.watch(tripsStreamProvider);
    final wishlistAsync = ref.watch(wishlistStreamProvider);
    final preferencesAsync = ref.watch(appPreferencesProvider);
    final authController = ref.watch(authControllerProvider);

    final visited = visitedAsync.valueOrNull ?? 0;
    final trips = tripsAsync.valueOrNull ?? const <TripRecord>[];
    final wishlistItems =
        wishlistAsync.valueOrNull ?? const <WishlistItemRecord>[];
    final preferences = preferencesAsync.valueOrNull ?? AppPreferences.defaults;
    final authUser = authController.currentUser;
    final displayName = preferences.displayName.trim().isNotEmpty
        ? preferences.displayName
        : (authUser?.displayName.trim().isNotEmpty == true
            ? authUser!.displayName
            : AppPreferences.defaults.displayName);
    final profileMeta = authUser?.email ?? preferences.homeBase;
    final homeBase =
        preferences.homeBase.trim().isEmpty ? profileMeta : preferences.homeBase;
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
          ProfileHeaderCard(
            displayName: displayName,
            homeBase: homeBase,
            photoUrl: authUser?.photoUrl,
            bio: preferences.bio,
          ),
          const SizedBox(height: 14),
          Row(
            children: <Widget>[
              Expanded(
                child: ProfileStatCard(
                  label: 'Countries',
                  value: visitedAsync.isLoading ? '...' : '$visited',
                  icon: Icons.public,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ProfileStatCard(
                  label: 'Trips',
                  value: tripsAsync.isLoading ? '...' : '${trips.length}',
                  icon: Icons.flight_takeoff,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ProfileStatCard(
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
                  leading: const Icon(Icons.people_outline_rounded),
                  title: const Text('Friends'),
                  subtitle: const Text('Invite friends and browse shared travel'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.go('/friends'),
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
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.logout),
                  title: const Text('Sign out'),
                  subtitle: const Text('Return to the auth screen'),
                  onTap: authController.isBusy
                      ? null
                      : () async {
                          try {
                            await ref.read(authControllerProvider).signOut();
                          } on AuthException catch (error) {
                            if (!context.mounted) {
                              return;
                            }
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(error.message)),
                            );
                          }
                        },
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
