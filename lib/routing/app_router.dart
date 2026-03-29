import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/auth_controller.dart';
import '../features/auth/auth_screen.dart';
import '../features/friends/friend_link_accept_screen.dart';
import '../features/friends/friend_profile_screen.dart';
import '../features/friends/friend_trip_detail_screen.dart';
import '../features/friends/friends_screen.dart';
import '../features/map/map_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/stats/stats_screen.dart';
import '../features/trips/add_trip_screen.dart';
import '../features/trips/trip_detail_screen.dart';
import '../features/trips/trips_screen.dart';
import '../features/wishlist/wishlist_add_idea_screen.dart';
import '../features/wishlist/wishlist_plan_manual_edit_screen.dart';
import '../features/wishlist/wishlist_plan_city_detail_screen.dart';
import '../features/wishlist/wishlist_plan_review_screen.dart';
import '../features/wishlist/wishlist_plan_screen.dart';
import '../features/wishlist/wishlist_screen.dart';
import '../widgets/frosted_squircle.dart';

final _rootNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'rootNavigator');
final _shellNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'shellNavigator');

const _inviteAppLinkHost = 'app.stepped.world';
const _inviteCustomScheme = 'stepped';

final appRouterProvider = Provider<GoRouter>((ref) {
  final authController = ref.read(authControllerProvider);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/launch',
    refreshListenable: authController,
    onException: (context, state, router) {
      final normalizedRoute = _normalizedInviteRoute(state.uri);
      if (normalizedRoute != null) {
        router.go(normalizedRoute);
      }
    },
    redirect: (context, state) {
      final onLaunchRoute = state.uri.path == '/launch';
      final onAuthRoute = state.uri.path == '/auth';
      final requestedLocation = state.uri.toString();
      final intendedLocation = onLaunchRoute ? '/' : requestedLocation;
      final from = state.uri.queryParameters['from'];
      if (!authController.isInitialized) {
        if (onLaunchRoute) {
          return null;
        }
        return '/launch';
      }

      if (!authController.isAuthenticated) {
        if (onAuthRoute) {
          return null;
        }
        final encoded = Uri.encodeComponent(intendedLocation);
        return '/auth?from=$encoded';
      }

      if (onAuthRoute || onLaunchRoute) {
        if (from != null && from.trim().isNotEmpty) {
          final decoded = Uri.decodeComponent(from);
          return decoded == '/launch' ? '/' : decoded;
        }
        return '/';
      }
      return null;
    },
    routes: <RouteBase>[
      GoRoute(
        path: '/launch',
        name: 'launch',
        pageBuilder: (context, state) {
          return const NoTransitionPage<void>(child: _AppLaunchScreen());
        },
      ),
      GoRoute(
        path: '/auth',
        name: 'auth',
        pageBuilder: (context, state) {
          return CustomTransitionPage<void>(
            key: state.pageKey,
            child: const AuthScreen(),
            transitionDuration: const Duration(milliseconds: 520),
            reverseTransitionDuration: const Duration(milliseconds: 420),
            transitionsBuilder: (
              context,
              animation,
              secondaryAnimation,
              child,
            ) {
              final curved = CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              );
              return FadeTransition(
                opacity: curved,
                child: ScaleTransition(
                  scale: Tween<double>(begin: 0.985, end: 1.0).animate(curved),
                  child: child,
                ),
              );
            },
          );
        },
      ),
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
                builder: (context, state) {
                  final rawWishlistId = state.uri.queryParameters['wishlistId'];
                  final wishlistItemId = int.tryParse(rawWishlistId ?? '');
                  return AddTripScreen(wishlistItemId: wishlistItemId);
                },
              ),
              GoRoute(
                path: 'view/:id',
                parentNavigatorKey: _rootNavigatorKey,
                builder: (context, state) {
                  final rawId = state.pathParameters['id'];
                  final id = int.tryParse(rawId ?? '');
                  if (id == null) {
                    return const _RouteErrorScreen(message: 'Invalid trip id');
                  }
                  return TripDetailScreen(tripId: id);
                },
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
                path: 'add',
                parentNavigatorKey: _rootNavigatorKey,
                builder: (context, state) => const WishlistAddIdeaScreen(),
              ),
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
                  return WishlistPlanReviewScreen(itemId: id);
                },
                routes: <RouteBase>[
                  GoRoute(
                    path: 'ai-edit',
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
                  GoRoute(
                    path: 'manual-edit',
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (context, state) {
                      final rawId = state.pathParameters['id'];
                      final id = int.tryParse(rawId ?? '');
                      if (id == null) {
                        return const _RouteErrorScreen(
                          message: 'Invalid wishlist item id',
                        );
                      }
                      return WishlistPlanManualEditScreen(itemId: id);
                    },
                  ),
                  GoRoute(
                    path: 'city/:cityIndex',
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (context, state) {
                      final rawId = state.pathParameters['id'];
                      final id = int.tryParse(rawId ?? '');
                      final rawCityIndex = state.pathParameters['cityIndex'];
                      final cityIndex = int.tryParse(rawCityIndex ?? '');
                      if (id == null || cityIndex == null) {
                        return const _RouteErrorScreen(
                          message: 'Invalid wishlist city route',
                        );
                      }
                      return WishlistPlanCityDetailScreen(
                        itemId: id,
                        cityIndex: cityIndex,
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
          GoRoute(
            path: '/friends',
            name: 'friends',
            pageBuilder: (context, state) {
              return const NoTransitionPage<void>(child: FriendsScreen());
            },
          ),
        ],
      ),
      GoRoute(
        path: '/profile',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const ProfileScreen(),
        routes: <RouteBase>[
          GoRoute(
            path: 'settings',
            parentNavigatorKey: _rootNavigatorKey,
            builder: (context, state) => const SettingsScreen(),
          ),
        ],
      ),
      GoRoute(
        path: '/friends/profile/:friendUserId',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final friendUserId = state.pathParameters['friendUserId'];
          if (friendUserId == null || friendUserId.trim().isEmpty) {
            return const _RouteErrorScreen(message: 'Invalid friend id');
          }
          return FriendProfileScreen(friendUserId: friendUserId);
        },
        routes: <RouteBase>[
          GoRoute(
            path: 'trips/:tripId',
            parentNavigatorKey: _rootNavigatorKey,
            builder: (context, state) {
              final friendUserId = state.pathParameters['friendUserId'];
              final tripId = state.pathParameters['tripId'];
              if (friendUserId == null ||
                  friendUserId.trim().isEmpty ||
                  tripId == null ||
                  tripId.trim().isEmpty) {
                return const _RouteErrorScreen(message: 'Invalid friend trip');
              }
              return FriendTripDetailScreen(
                friendUserId: friendUserId,
                tripId: tripId,
              );
            },
          ),
        ],
      ),
      GoRoute(
        path: '/friends/add/:token',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final token = state.pathParameters['token'];
          if (token == null || token.trim().isEmpty) {
            return const _RouteErrorScreen(message: 'Invalid friend invite');
          }
          return FriendLinkAcceptScreen(token: token);
        },
      ),
      GoRoute(
        path: '/stats',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const StatsScreen(),
      ),
    ],
  );
});

String? _normalizedInviteRoute(Uri uri) {
  final scheme = uri.scheme.toLowerCase();
  late final List<String> segments;

  if (scheme == _inviteCustomScheme) {
    segments = <String>[
      if (uri.host.isNotEmpty) uri.host,
      ...uri.pathSegments.where((segment) => segment.isNotEmpty),
    ];
  } else if (scheme == 'https' &&
      uri.host.toLowerCase() == _inviteAppLinkHost) {
    segments = uri.pathSegments.where((segment) => segment.isNotEmpty).toList();
  } else {
    return null;
  }

  final isInviteRoute = segments.length >= 3 &&
      segments[0].toLowerCase() == 'friends' &&
      segments[1].toLowerCase() == 'add';
  if (!isInviteRoute) {
    return null;
  }

  final token = segments[2].trim();
  if (token.isEmpty) {
    return null;
  }

  final normalized = Uri(
    path: '/friends/add/$token',
    queryParameters: uri.queryParameters.isEmpty ? null : uri.queryParameters,
  );
  return normalized.toString();
}

class _AppShell extends StatelessWidget {
  const _AppShell({required this.location, required this.child});

  static const List<_ShellDestination> _destinations = <_ShellDestination>[
    _ShellDestination(
      label: 'Map',
      icon: Icons.public_outlined,
      selectedIcon: Icons.public,
      route: '/',
    ),
    _ShellDestination(
      label: 'Trips',
      icon: Icons.flight_takeoff_outlined,
      selectedIcon: Icons.flight_takeoff,
      route: '/trips',
    ),
    _ShellDestination(
      label: 'Wishlist',
      icon: Icons.favorite_border,
      selectedIcon: Icons.favorite,
      route: '/wishlist',
    ),
    _ShellDestination(
      label: 'Friends',
      icon: Icons.people_outline_rounded,
      selectedIcon: Icons.people_rounded,
      route: '/friends',
    ),
  ];

  final String location;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final selectedIndex = _indexForLocation(location);
    final isFloatingNavRoute = selectedIndex >= 0;

    return Scaffold(
      extendBody: isFloatingNavRoute,
      resizeToAvoidBottomInset: location != '/',
      body: child,
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: FrostedSquircle(
          radius: 34,
          blurSigma: 20,
          color: colorScheme.surface.withValues(
            alpha: isFloatingNavRoute ? 0.66 : 0.92,
          ),
          borderColor: colorScheme.outlineVariant.withValues(alpha: 0.16),
          shadowColor: colorScheme.primary.withValues(alpha: 0.12),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            children: List<Widget>.generate(_destinations.length, (index) {
              final destination = _destinations[index];
              return Expanded(
                child: _ShellNavItem(
                  destination: destination,
                  selected: selectedIndex == index,
                  onTap: () => _onDestinationSelected(context, index),
                ),
              );
            }),
          ),
        ),
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
    if (location.startsWith('/friends')) {
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
        context.go('/friends');
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

class _AppLaunchScreen extends StatelessWidget {
  const _AppLaunchScreen();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              colorScheme.surface,
              colorScheme.surfaceContainerLow,
              colorScheme.surfaceContainer,
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: FrostedSquircle(
              radius: 36,
              blurSigma: 22,
              color: colorScheme.surface.withValues(alpha: 0.58),
              borderColor: colorScheme.primaryContainer.withValues(alpha: 0.16),
              shadowColor: colorScheme.primary.withValues(alpha: 0.08),
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  DecoratedBox(
                    decoration: ShapeDecoration(
                      shape: squircleShape(28),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: <Color>[
                          colorScheme.primary,
                          colorScheme.primaryContainer,
                        ],
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Image.asset(
                        'assets/branding/stepped_monochrome_logo.png',
                        width: 44,
                        height: 44,
                        color: colorScheme.onPrimary,
                        filterQuality: FilterQuality.high,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'STEPPED',
                    style: textTheme.titleLarge?.copyWith(
                      letterSpacing: 3.0,
                      fontSize: 26,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Reopening your travel journal...',
                    style: textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: 140,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        minHeight: 4,
                        backgroundColor:
                            colorScheme.surfaceContainerHighest.withValues(
                          alpha: 0.75,
                        ),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          colorScheme.primaryContainer,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ShellDestination {
  const _ShellDestination({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.route,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final String route;
}

class _ShellNavItem extends StatelessWidget {
  const _ShellNavItem({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final _ShellDestination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final iconColor = selected
        ? colorScheme.onSurface
        : colorScheme.onSurfaceVariant.withValues(alpha: 0.82);
    final labelColor = selected
        ? colorScheme.onSurface
        : colorScheme.onSurfaceVariant.withValues(alpha: 0.74);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        customBorder: squircleShape(24),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                selected ? destination.selectedIcon : destination.icon,
                size: 22,
                color: iconColor,
              ),
              const SizedBox(height: 6),
              Text(
                destination.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: labelColor,
                      letterSpacing: 0.8,
                    ),
              ),
              const SizedBox(height: 6),
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                width: selected ? 18 : 6,
                height: 4,
                decoration: BoxDecoration(
                  color: selected
                      ? colorScheme.primaryContainer
                      : colorScheme.primaryContainer.withValues(alpha: 0.0),
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: selected
                      ? <BoxShadow>[
                          BoxShadow(
                            color: colorScheme.primaryContainer.withValues(
                              alpha: 0.55,
                            ),
                            blurRadius: 12,
                            offset: const Offset(0, 3),
                          ),
                        ]
                      : const <BoxShadow>[],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
