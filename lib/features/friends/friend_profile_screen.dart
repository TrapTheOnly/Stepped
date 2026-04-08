import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../widgets/editorial_overlay_page_shell.dart';
import '../../widgets/frosted_squircle.dart';
import '../../widgets/person_avatar.dart';
import '../social/social_api_client.dart';
import '../social/social_models.dart';
import '../social/social_state.dart';
import 'widgets/read_only_globe_card.dart';

const _friendProfileBottomPadding = 64.0;

enum _FriendProfileTab { trips, wishlist }

class FriendProfileScreen extends ConsumerStatefulWidget {
  const FriendProfileScreen({
    super.key,
    required this.friendUserId,
  });

  final String friendUserId;

  @override
  ConsumerState<FriendProfileScreen> createState() =>
      _FriendProfileScreenState();
}

class _FriendProfileScreenState extends ConsumerState<FriendProfileScreen>
    with WidgetsBindingObserver {
  DateTime? _lastRefreshAt;
  bool _isRemoving = false;
  _FriendProfileTab _selectedTab = _FriendProfileTab.trips;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _refreshProfile(force: true);
      }
    });
  }

  @override
  void didUpdateWidget(covariant FriendProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.friendUserId != widget.friendUserId) {
      _refreshProfile(force: true);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshProfile();
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(friendProfileProvider(widget.friendUserId));
    final colorScheme = Theme.of(context).colorScheme;

    return EditorialOverlayPageShell(
      background: const _FriendProfileAtmosphere(),
      backgroundColor: colorScheme.surface,
      topBar: _TopBar(
        title: 'Profile',
        isRemoving: _isRemoving,
        onBack: () => _popOrGoToFriends(context),
        onRemove: _isRemoving ? null : _confirmRemove,
      ),
      bodyBuilder: (context, topContentInset, __) {
        return profileAsync.when(
          skipLoadingOnRefresh: true,
          skipLoadingOnReload: true,
          loading: () => _FriendProfileScrollView(
            topPadding: topContentInset,
            children: <Widget>[
              _FriendHorizontalPadding(
                child: _StatusCard(
                  title: 'Loading public profile',
                  message:
                      'Bringing in their map, stats, and shared travel plans.',
                  showProgress: true,
                ),
              ),
            ],
          ),
          error: (error, _) => _FriendProfileScrollView(
            topPadding: topContentInset,
            children: <Widget>[
              _FriendHorizontalPadding(
                child: _StatusCard(
                  title: 'Profile unavailable',
                  message: _messageForError(error),
                ),
              ),
            ],
          ),
          data: (profile) => _FriendProfileScrollView(
            topPadding: topContentInset,
            children: <Widget>[
              _FriendHorizontalPadding(
                child: _HeroCard(friend: profile.friend),
              ),
              const SizedBox(height: 18),
              _FriendHorizontalPadding(
                child: ReadOnlyGlobeCard(
                  visitedCountryCodes: profile.friend.visitedCountries
                      .map((entry) => entry.countryCode)
                      .toList(growable: false),
                  title: 'Map',
                  subtitle: '',
                ),
              ),
              const SizedBox(height: 22),
              _FriendHorizontalPadding(
                child: _TabPicker(
                  selectedTab: _selectedTab,
                  onSelected: (tab) {
                    setState(() {
                      _selectedTab = tab;
                    });
                  },
                ),
              ),
              const SizedBox(height: 18),
              _FriendHorizontalPadding(
                child: _SectionLabel(
                  title: _selectedTab == _FriendProfileTab.trips
                      ? 'Trips'
                      : 'Wishlist Ideas',
                ),
              ),
              const SizedBox(height: 14),
              ...(_selectedTab == _FriendProfileTab.trips
                  ? _buildTripSection(context, profile)
                  : _buildWishlistSection(context, profile)),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _buildTripSection(
    BuildContext context,
    FriendProfileResponse profile,
  ) {
    if (profile.trips.isEmpty) {
      return const <Widget>[
        _FriendHorizontalPadding(
          child: _StatusCard(
            title: 'No public trips yet',
            message:
                'This friend has not shared any trips through the social profile yet.',
          ),
        ),
      ];
    }

    return <Widget>[
      for (final trip in profile.trips) ...<Widget>[
        _FriendHorizontalPadding(
          child: _TripCard(
            trip: trip,
            onTap: () => context.push(
              '/friends/profile/${widget.friendUserId}/trips/${Uri.encodeComponent(_tripRouteId(trip))}',
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    ];
  }

  List<Widget> _buildWishlistSection(
    BuildContext context,
    FriendProfileResponse profile,
  ) {
    if (profile.wishlistItems.isEmpty) {
      return <Widget>[
        _FriendHorizontalPadding(
          child: _StatusCard(
            title: profile.isWishlistPrivate
                ? 'Wishlist is private'
                : 'No shared wishlist ideas',
            message: _wishlistEmptyMessage(profile),
          ),
        ),
      ];
    }

    return <Widget>[
      for (final item in profile.wishlistItems) ...<Widget>[
        _FriendHorizontalPadding(
          child: _WishlistCard(
            item: item,
            onTap: () => context.push(
              '/friends/profile/${widget.friendUserId}/wishlist/${Uri.encodeComponent(item.id)}',
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    ];
  }

  String _messageForError(Object error) {
    if (error is SocialApiException) {
      return error.message;
    }
    return 'We could not load this friend profile right now.';
  }

  void _refreshProfile({bool force = false}) {
    final now = DateTime.now();
    if (!force && _lastRefreshAt != null) {
      final elapsed = now.difference(_lastRefreshAt!);
      if (elapsed < const Duration(seconds: 12)) {
        return;
      }
    }
    _lastRefreshAt = now;
    ref.invalidate(friendProfileProvider(widget.friendUserId));
  }

  void _popOrGoToFriends(BuildContext context) {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go('/friends');
  }

  Future<void> _confirmRemove() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Remove friend?'),
          content: const Text(
            'This removes the connection from your circle. You can add each other again later with a new invite link.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Remove'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    final session = ref.read(socialSessionProvider);
    if (session == null) {
      return;
    }

    setState(() {
      _isRemoving = true;
    });

    try {
      await ref.read(socialApiClientProvider).deleteFriend(
            accessToken: session.accessToken,
            friendUserId: widget.friendUserId,
          );
      if (!mounted) {
        return;
      }
      ref.invalidate(socialFriendsProvider);
      ref.invalidate(friendsHubProvider);
      ref.invalidate(socialMeProvider);
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(content: Text('Friend removed')),
      );
      context.go('/friends');
    } on SocialApiException catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isRemoving = false;
        });
      }
    }
  }
}

String _tripRouteId(SocialTripSummary trip) {
  final normalizedId = trip.id.trim();
  if (normalizedId.isNotEmpty) {
    return normalizedId;
  }
  return '${trip.countryCode}-${trip.startDate}-${trip.endDate}';
}

String _wishlistEmptyMessage(FriendProfileResponse profile) {
  if (profile.isWishlistPrivate) {
    return 'This user keeps wishlist private.';
  }
  if (profile.isWishlistSharedWithFriends) {
    return 'No shared wishlist ideas yet.';
  }
  return 'This friend is either keeping wishlist plans private or has not shared any saved ideas yet.';
}

class _FriendProfileAtmosphere extends StatelessWidget {
  const _FriendProfileAtmosphere();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            colorScheme.surface.withValues(alpha: 0.08),
            colorScheme.surface,
          ],
        ),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(-0.9, -0.8),
            radius: 1.0,
            colors: <Color>[
              colorScheme.primary.withValues(alpha: 0.10),
              Colors.transparent,
            ],
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.title,
    required this.onBack,
    required this.onRemove,
    required this.isRemoving,
  });

  final String title;
  final VoidCallback onBack;
  final VoidCallback? onRemove;
  final bool isRemoving;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return FrostedSquircle(
      radius: 28,
      blurSigma: 16,
      color: colorScheme.surface.withValues(alpha: 0.56),
      borderColor: colorScheme.primaryContainer.withValues(alpha: 0.14),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: SizedBox(
        height: 28,
        child: Stack(
          alignment: Alignment.center,
          children: <Widget>[
            Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                onPressed: onBack,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                icon: Icon(
                  Icons.arrow_back_rounded,
                  size: 24,
                  color: colorScheme.onSurface,
                ),
              ),
            ),
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: colorScheme.onSurface,
                    letterSpacing: 0.8,
                  ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                onPressed: onRemove,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                icon: isRemoving
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: colorScheme.error,
                        ),
                      )
                    : Icon(
                        Icons.person_remove_outlined,
                        size: 22,
                        color: colorScheme.error,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FriendProfileScrollView extends StatelessWidget {
  const _FriendProfileScrollView({
    required this.children,
    this.topPadding = 0,
  });

  final List<Widget> children;
  final double topPadding;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            0,
            topPadding,
            0,
            _friendProfileBottomPadding,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        );
      },
    );
  }
}

class _FriendHorizontalPadding extends StatelessWidget {
  const _FriendHorizontalPadding({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: child,
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.friend});

  final FriendProfile friend;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return FrostedSquircle(
      radius: 30,
      blurSigma: 18,
      color: colorScheme.surface.withValues(alpha: 0.72),
      borderColor: colorScheme.primaryContainer.withValues(alpha: 0.16),
      shadowColor: colorScheme.primary.withValues(alpha: 0.08),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              PersonAvatar(
                displayName: friend.displayName,
                photoUrl: friend.photoUrl,
                radius: 28,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      friend.displayName,
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      friend.homeBase.isEmpty
                          ? 'Home base not set'
                          : friend.homeBase,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (friend.bio.isNotEmpty) ...<Widget>[
            const SizedBox(height: 16),
            Text(
              friend.bio,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    height: 1.35,
                  ),
            ),
          ],
          const SizedBox(height: 18),
          Row(
            children: <Widget>[
              Expanded(
                child: _MetricCard(
                  label: 'Trips',
                  value: '${friend.stats.totalTrips}',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MetricCard(
                  label: 'Countries',
                  value: '${friend.stats.visitedCountriesCount}',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MetricCard(
                  label: 'Friends',
                  value: '${friend.stats.totalFriends}',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.76),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(value, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 2),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TabPicker extends StatelessWidget {
  const _TabPicker({
    required this.selectedTab,
    required this.onSelected,
  });

  final _FriendProfileTab selectedTab;
  final ValueChanged<_FriendProfileTab> onSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return FrostedSquircle(
      radius: 28,
      blurSigma: 18,
      color: scheme.surface.withValues(alpha: 0.68),
      borderColor: scheme.primaryContainer.withValues(alpha: 0.14),
      padding: const EdgeInsets.all(6),
      child: Row(
        children: _FriendProfileTab.values.map((tab) {
          final isSelected = tab == selectedTab;
          final label =
              tab == _FriendProfileTab.trips ? 'Trips' : 'Wishlist Ideas';
          return Expanded(
            child: GestureDetector(
              onTap: () => onSelected(tab),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  color: isSelected
                      ? scheme.primaryContainer.withValues(alpha: 0.7)
                      : Colors.transparent,
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: isSelected
                            ? scheme.onPrimaryContainer
                            : scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
            ),
          );
        }).toList(growable: false),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.title,
    required this.message,
    this.showProgress = false,
  });

  final String title;
  final String message;
  final bool showProgress;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return FrostedSquircle(
      radius: 30,
      blurSigma: 18,
      color: colorScheme.surface.withValues(alpha: 0.72),
      borderColor: colorScheme.primaryContainer.withValues(alpha: 0.16),
      shadowColor: colorScheme.primary.withValues(alpha: 0.08),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            message,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
          ),
          if (showProgress) ...<Widget>[
            const SizedBox(height: 18),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: const LinearProgressIndicator(minHeight: 6),
            ),
          ],
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
    );
  }
}

class _TripCard extends StatelessWidget {
  const _TripCard({
    required this.trip,
    required this.onTap,
  });

  final SocialTripSummary trip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final borderRadius = BorderRadius.circular(30);
    final start = DateTime.fromMillisecondsSinceEpoch(trip.startDate);
    final end = DateTime.fromMillisecondsSinceEpoch(trip.endDate);
    final dateLabel =
        '${DateFormat.yMMMd().format(start)} - ${DateFormat.yMMMd().format(end)}';

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: colorScheme.primary.withValues(alpha: 0.08),
            blurRadius: 32,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: SizedBox(
              height: 224,
              child: Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  _TripArtwork(
                    url: trip.coverImageUrl,
                    countryName: trip.countryName,
                  ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: <Color>[
                          Colors.black.withValues(alpha: 0.08),
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.72),
                        ],
                        stops: const <double>[0, 0.34, 1],
                      ),
                    ),
                  ),
                  Positioned(
                    top: 16,
                    right: 16,
                    child: DecoratedBox(
                      decoration: ShapeDecoration(
                        color: Colors.white.withValues(alpha: 0.16),
                        shape: const StadiumBorder(),
                      ),
                      child: const Padding(
                        padding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Icon(
                              Icons.open_in_new_rounded,
                              size: 16,
                              color: Colors.white,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Open trip',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 18,
                    right: 18,
                    bottom: 18,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          trip.countryName,
                          style: Theme.of(context)
                              .textTheme
                              .displaySmall
                              ?.copyWith(
                                color: Colors.white,
                                fontSize: 34,
                                height: 0.98,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          dateLabel,
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Colors.white.withValues(alpha: 0.86),
                                    fontWeight: FontWeight.w600,
                                  ),
                        ),
                        if (trip.cities.trim().isNotEmpty) ...<Widget>[
                          const SizedBox(height: 4),
                          Text(
                            trip.cities,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: Colors.white.withValues(alpha: 0.82),
                                ),
                          ),
                        ],
                      ],
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

class _TripArtwork extends StatelessWidget {
  const _TripArtwork({
    required this.url,
    required this.countryName,
  });

  final String? url;
  final String countryName;

  @override
  Widget build(BuildContext context) {
    final normalizedUrl = url?.trim();
    if (normalizedUrl != null && normalizedUrl.isNotEmpty) {
      return Image.network(
        normalizedUrl,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) =>
            _TripPlaceholder(countryName: countryName),
      );
    }
    return _TripPlaceholder(countryName: countryName);
  }
}

class _TripPlaceholder extends StatelessWidget {
  const _TripPlaceholder({required this.countryName});

  final String countryName;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            colorScheme.primaryContainer.withValues(alpha: 0.88),
            colorScheme.secondaryContainer.withValues(alpha: 0.82),
            colorScheme.surfaceContainerHighest.withValues(alpha: 0.9),
          ],
        ),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(-0.5, -0.6),
            radius: 1.1,
            colors: <Color>[
              colorScheme.primary.withValues(alpha: 0.18),
              Colors.transparent,
            ],
          ),
        ),
        child: Center(
          child: Icon(
            Icons.public_rounded,
            size: 68,
            color: colorScheme.onPrimaryContainer.withValues(alpha: 0.42),
          ),
        ),
      ),
    );
  }
}

class _WishlistCard extends StatelessWidget {
  const _WishlistCard({
    required this.item,
    required this.onTap,
  });

  final SharedWishlistItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final borderRadius = BorderRadius.circular(30);
    final dateLabel = _sharedWishlistDateLabel(
      startDate: item.plannedStartDate,
      endDate: item.plannedEndDate,
    );
    final meta = <String>[
      if (item.countryName.trim().isNotEmpty) item.countryName.trim(),
      if (item.plannedCities.trim().isNotEmpty) item.plannedCities.trim(),
      if (dateLabel != null) dateLabel,
    ];

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: colorScheme.primary.withValues(alpha: 0.08),
            blurRadius: 28,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: SizedBox(
              height: 220,
              child: Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  _WishlistArtwork(
                    imageUrl: item.imageUrl,
                  ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: <Color>[
                          Colors.black.withValues(alpha: 0.06),
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.72),
                        ],
                        stops: const <double>[0, 0.36, 1],
                      ),
                    ),
                  ),
                  Positioned(
                    top: 16,
                    right: 16,
                    child: DecoratedBox(
                      decoration: ShapeDecoration(
                        color: Colors.white.withValues(alpha: 0.16),
                        shape: const StadiumBorder(),
                      ),
                      child: const Padding(
                        padding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Icon(
                              Icons.open_in_new_rounded,
                              size: 16,
                              color: Colors.white,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Open idea',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 18,
                    right: 18,
                    bottom: 18,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          item.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context)
                              .textTheme
                              .displaySmall
                              ?.copyWith(
                                color: Colors.white,
                                fontSize: 32,
                                height: 0.98,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        if (meta.isNotEmpty) ...<Widget>[
                          const SizedBox(height: 8),
                          Text(
                            meta.join(' · '),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: Colors.white.withValues(alpha: 0.86),
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ],
                        if ((item.notes ?? '').trim().isNotEmpty) ...<Widget>[
                          const SizedBox(height: 10),
                          Text(
                            item.notes!.trim(),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                  color: Colors.white.withValues(alpha: 0.78),
                                  height: 1.3,
                                ),
                          ),
                        ],
                      ],
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

class _WishlistArtwork extends StatelessWidget {
  const _WishlistArtwork({
    required this.imageUrl,
  });

  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final normalizedUrl = imageUrl?.trim();
    if (normalizedUrl != null && normalizedUrl.isNotEmpty) {
      return Image.network(
        normalizedUrl,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const _WishlistPlaceholder(),
      );
    }
    return const _WishlistPlaceholder();
  }
}

class _WishlistPlaceholder extends StatelessWidget {
  const _WishlistPlaceholder();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            colorScheme.surfaceContainerHigh.withValues(alpha: 0.92),
            colorScheme.surfaceContainer.withValues(alpha: 0.84),
            colorScheme.surfaceContainerLow.withValues(alpha: 0.94),
          ],
        ),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0.6, -0.2),
            radius: 1.2,
            colors: <Color>[
              colorScheme.primary.withValues(alpha: 0.16),
              Colors.transparent,
            ],
          ),
        ),
        child: Center(
          child: Icon(
            Icons.travel_explore_rounded,
            size: 72,
            color: colorScheme.onSurface.withValues(alpha: 0.22),
          ),
        ),
      ),
    );
  }
}

String? _sharedWishlistDateLabel({
  required int? startDate,
  required int? endDate,
}) {
  final formatter = DateFormat('MMM d, y');
  final start =
      startDate == null ? null : DateTime.fromMillisecondsSinceEpoch(startDate);
  final end =
      endDate == null ? null : DateTime.fromMillisecondsSinceEpoch(endDate);
  if (start != null && end != null) {
    return '${formatter.format(start)} - ${formatter.format(end)}';
  }
  if (start != null) {
    return 'Starts ${formatter.format(start)}';
  }
  if (end != null) {
    return 'Until ${formatter.format(end)}';
  }
  return null;
}
