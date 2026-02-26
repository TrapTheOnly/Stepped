import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/map/map_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/search/search_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/stats/stats_screen.dart';
import '../features/trips/add_trip_screen.dart';
import '../features/trips/trips_screen.dart';
import '../features/wishlist/wishlist_plan_screen.dart';
import '../features/wishlist/wishlist_screen.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'rootNavigator');
final _shellNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'shellNavigator');

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/',
    routes: <RouteBase>[
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (context, state, child) {
          return _AppShell(location: state.uri.path, child: child);
        },
        routes: <RouteBase>[
          GoRoute(
            path: '/',
            name: 'map',
            pageBuilder: (context, state) {
              return const NoTransitionPage<void>(child: MapScreen());
            },
          ),
          GoRoute(
            path: '/trips',
            name: 'trips',
            pageBuilder: (context, state) {
              return const NoTransitionPage<void>(child: TripsScreen());
            },
            routes: <RouteBase>[
              GoRoute(
                path: 'add',
                parentNavigatorKey: _rootNavigatorKey,
                builder: (context, state) => const AddTripScreen(),
              ),
              GoRoute(
                path: 'edit/:id',
                parentNavigatorKey: _rootNavigatorKey,
                builder: (context, state) {
                  final rawId = state.pathParameters['id'];
                  final id = int.tryParse(rawId ?? '');
                  if (id == null) {
                    return const _RouteErrorScreen(message: 'Invalid trip id');
                  }
                  return AddTripScreen(tripId: id);
                },
              ),
            ],
          ),
          GoRoute(
            path: '/wishlist',
            name: 'wishlist',
            pageBuilder: (context, state) {
              return const NoTransitionPage<void>(child: WishlistScreen());
            },
            routes: <RouteBase>[
              GoRoute(
                path: 'plan/:id',
                parentNavigatorKey: _rootNavigatorKey,
                builder: (context, state) {
                  final rawId = state.pathParameters['id'];
                  final id = int.tryParse(rawId ?? '');
                  if (id == null) {
                    return const _RouteErrorScreen(
                      message: 'Invalid wishlist item id',
                    );
                  }
                  return WishlistPlanScreen(itemId: id);
                },
              ),
            ],
          ),
          GoRoute(
            path: '/profile',
            name: 'profile',
            pageBuilder: (context, state) {
              return const NoTransitionPage<void>(child: ProfileScreen());
            },
            routes: <RouteBase>[
              GoRoute(
                path: 'settings',
                parentNavigatorKey: _rootNavigatorKey,
                builder: (context, state) => const SettingsScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/search',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const SearchScreen(),
      ),
      GoRoute(
        path: '/stats',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const StatsScreen(),
      ),
    ],
  );
});

class _AppShell extends StatelessWidget {
  const _AppShell({required this.location, required this.child});

  final String location;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _indexForLocation(location),
        onDestinationSelected: (index) => _onDestinationSelected(context, index),
        destinations: const <NavigationDestination>[
          NavigationDestination(
            icon: Icon(Icons.public_outlined),
            selectedIcon: Icon(Icons.public),
            label: 'Map',
          ),
          NavigationDestination(
            icon: Icon(Icons.flight_takeoff_outlined),
            selectedIcon: Icon(Icons.flight_takeoff),
            label: 'Trips',
          ),
          NavigationDestination(
            icon: Icon(Icons.favorite_border),
            selectedIcon: Icon(Icons.favorite),
            label: 'Wishlist',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  int _indexForLocation(String location) {
    if (location.startsWith('/trips')) {
      return 1;
    }
    if (location.startsWith('/wishlist')) {
      return 2;
    }
    if (location.startsWith('/profile')) {
      return 3;
    }
    return 0;
  }

  void _onDestinationSelected(BuildContext context, int index) {
    switch (index) {
      case 0:
        context.go('/');
        return;
      case 1:
        context.go('/trips');
        return;
      case 2:
        context.go('/wishlist');
        return;
      case 3:
        context.go('/profile');
        return;
    }
  }
}

class _RouteErrorScreen extends StatelessWidget {
  const _RouteErrorScreen({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Route Error')),
      body: SafeArea(
        child: Center(child: Text(message)),
      ),
    );
  }
}
