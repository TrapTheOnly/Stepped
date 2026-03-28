import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../widgets/frosted_squircle.dart';
import '../../widgets/person_avatar.dart';
import '../social/social_api_client.dart';
import '../social/social_models.dart';
import '../social/social_state.dart';
import 'widgets/read_only_globe_card.dart';

const _friendProfileTopOverlayClearance = 114.0;
const _friendProfileBottomPadding = 64.0;

class FriendProfileScreen extends ConsumerWidget {
  const FriendProfileScreen({
    super.key,
    required this.friendUserId,
  });

  final String friendUserId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(friendProfileProvider(friendUserId));
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBody: true,
      body: ColoredBox(
        color: colorScheme.surface,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            const Positioned.fill(
              child: IgnorePointer(child: _FriendProfileAtmosphere()),
            ),
            Positioned.fill(
              child: profileAsync.when(
                loading: () => const _FriendProfileScrollView(
                  children: <Widget>[
                    SizedBox(height: _friendProfileTopOverlayClearance),
                    _FriendHorizontalPadding(
                      child: _FriendProfileStatusCard(
                        title: 'Loading public profile',
                        message:
                            'Bringing in their map, stats, and shared trips.',
                        showProgress: true,
                      ),
                    ),
                  ],
                ),
                error: (error, _) => _FriendProfileScrollView(
                  children: <Widget>[
                    const SizedBox(height: _friendProfileTopOverlayClearance),
                    _FriendHorizontalPadding(
                      child: _FriendProfileStatusCard(
                        title: 'Profile unavailable',
                        message: _messageForError(error),
                      ),
                    ),
                  ],
                ),
                data: (profile) => _FriendProfileScrollView(
                  children: <Widget>[
                    const SizedBox(height: _friendProfileTopOverlayClearance),
                    _FriendHorizontalPadding(
                      child: _FriendHeroCard(friend: profile.friend),
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
                    const SizedBox(height: 28),
                    const _FriendHorizontalPadding(
                      child: _FriendSectionHeading(
                        eyebrow: 'Journal',
                        title: 'Trips',
                        subtitle:
                            'Open a trip to see the shared cities, dates, and notes from their public journal.',
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (profile.trips.isEmpty)
                      const _FriendHorizontalPadding(
                        child: _FriendProfileStatusCard(
                          title: 'No public trips yet',
                          message:
                              'This friend has not shared any trips through the social profile yet.',
                        ),
                      )
                    else
                      for (final trip in profile.trips) ...<Widget>[
                        _FriendHorizontalPadding(
                          child: _FriendTripCard(
                            trip: trip,
                            onTap: () => context.push(
                              '/friends/profile/$friendUserId/trips/${Uri.encodeComponent(_tripRouteId(trip))}',
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    const SizedBox(height: 28),
                    const _FriendHorizontalPadding(
                      child: _FriendSectionHeading(
                        eyebrow: 'Wishlist',
                        title: 'Shared spots',
                        subtitle:
                            'Saved wishlist ideas they have chosen to share with friends.',
                      ),
                    ),
                    const SizedBox(height: 18),
                    if (profile.wishlistItems.isEmpty)
                      _FriendHorizontalPadding(
                        child: _FriendProfileStatusCard(
                          title: profile.isWishlistPrivate
                              ? 'Wishlist is private'
                              : 'No shared wishlist items',
                          message: _wishlistEmptyMessage(profile),
                        ),
                      )
                    else
                      for (final item in profile.wishlistItems) ...<Widget>[
                        _FriendHorizontalPadding(
                          child: _SharedWishlistCard(item: item),
                        ),
                        const SizedBox(height: 16),
                      ],
                    const SizedBox(height: 18),
                    _FriendHorizontalPadding(
                      child: _RemoveFriendButton(friendUserId: friendUserId),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: _FriendDetailTopBar(
                    title: 'Friend Profile',
                    onBack: () => _popOrGoToFriends(context),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _messageForError(Object error) {
    if (error is SocialApiException) {
      return error.message;
    }
    return 'We could not load this friend profile right now.';
  }

  void _popOrGoToFriends(BuildContext context) {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go('/friends');
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
    return 'No shared wishlist items yet.';
  }
  return 'This friend is either keeping wishlist plans private or has not shared any saved spots yet.';
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

class _FriendDetailTopBar extends StatelessWidget {
  const _FriendDetailTopBar({
    required this.title,
    required this.onBack,
  });

  final String title;
  final VoidCallback onBack;

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
          ],
        ),
      ),
    );
  }
}

class _FriendProfileScrollView extends StatelessWidget {
  const _FriendProfileScrollView({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding:
              const EdgeInsets.fromLTRB(0, 0, 0, _friendProfileBottomPadding),
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

class _FriendHeroCard extends StatelessWidget {
  const _FriendHeroCard({required this.friend});

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
                child: _FriendMetricCard(
                  label: 'Trips',
                  value: '${friend.stats.totalTrips}',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _FriendMetricCard(
                  label: 'Countries',
                  value: '${friend.stats.visitedCountriesCount}',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _FriendMetricCard(
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

class _FriendMetricCard extends StatelessWidget {
  const _FriendMetricCard({
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

class _FriendSectionHeading extends StatelessWidget {
  const _FriendSectionHeading({
    required this.eyebrow,
    required this.title,
    required this.subtitle,
  });

  final String eyebrow;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          eyebrow.toUpperCase(),
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                letterSpacing: 1.6,
                color: colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          title,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                height: 1.35,
              ),
        ),
      ],
    );
  }
}

class _FriendProfileStatusCard extends StatelessWidget {
  const _FriendProfileStatusCard({
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

class _FriendTripCard extends StatelessWidget {
  const _FriendTripCard({
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
    final dateLabel = '${DateFormat.yMMMd().format(start)} - '
        '${DateFormat.yMMMd().format(end)}';

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
                        if ((trip.notes ?? '').trim().isNotEmpty) ...<Widget>[
                          const SizedBox(height: 10),
                          Text(
                            trip.notes!.trim(),
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

class _SharedWishlistCard extends StatelessWidget {
  const _SharedWishlistCard({required this.item});

  final SharedWishlistItem item;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final createdAt = item.createdAt;
    final createdLabel =
        createdAt == null ? null : DateFormat.yMMMd().format(createdAt);
    final hasDates =
        item.plannedStartDate != null || item.plannedEndDate != null;
    final dateLabel = hasDates
        ? _sharedWishlistDateLabel(
            startDate: item.plannedStartDate,
            endDate: item.plannedEndDate,
          )
        : null;
    final plannedCities = item.plannedCities.trim();
    final countryName = item.countryName.trim();
    final notes = item.notes?.trim() ?? '';
    final imageUrl = item.imageUrl?.trim() ?? '';

    return FrostedSquircle(
      radius: 30,
      blurSigma: 18,
      color: colorScheme.surface.withValues(alpha: 0.72),
      borderColor: colorScheme.primaryContainer.withValues(alpha: 0.16),
      shadowColor: colorScheme.primary.withValues(alpha: 0.08),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (imageUrl.isNotEmpty) ...<Widget>[
            ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _SharedWishlistImageFallback(
                    title: item.title,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          Text(
            item.title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              if (countryName.isNotEmpty)
                _SharedWishlistMetaChip(
                  icon: Icons.public_rounded,
                  label: countryName,
                ),
              if (plannedCities.isNotEmpty)
                _SharedWishlistMetaChip(
                  icon: Icons.location_city_rounded,
                  label: plannedCities,
                ),
              if (dateLabel != null)
                _SharedWishlistMetaChip(
                  icon: Icons.schedule_rounded,
                  label: dateLabel,
                ),
              if (createdLabel != null)
                _SharedWishlistMetaChip(
                  icon: Icons.bookmark_added_rounded,
                  label: 'Saved $createdLabel',
                ),
            ],
          ),
          if (notes.isNotEmpty) ...<Widget>[
            const SizedBox(height: 14),
            Text(
              notes,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    height: 1.35,
                  ),
            ),
          ],
        ],
      ),
    );
  }
}

String _sharedWishlistDateLabel({
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
  return '';
}

class _SharedWishlistMetaChip extends StatelessWidget {
  const _SharedWishlistMetaChip({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: ShapeDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.44),
        shape: const StadiumBorder(),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 16, color: colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SharedWishlistImageFallback extends StatelessWidget {
  const _SharedWishlistImageFallback({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            colorScheme.primaryContainer.withValues(alpha: 0.6),
            colorScheme.surfaceContainerHighest.withValues(alpha: 0.72),
          ],
        ),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
      ),
    );
  }
}

class _RemoveFriendButton extends ConsumerStatefulWidget {
  const _RemoveFriendButton({required this.friendUserId});

  final String friendUserId;

  @override
  ConsumerState<_RemoveFriendButton> createState() =>
      _RemoveFriendButtonState();
}

class _RemoveFriendButtonState extends ConsumerState<_RemoveFriendButton> {
  bool _isRemoving = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return FrostedSquircle(
      radius: 28,
      blurSigma: 18,
      color: scheme.errorContainer.withValues(alpha: 0.42),
      borderColor: scheme.error.withValues(alpha: 0.18),
      shadowColor: scheme.error.withValues(alpha: 0.08),
      padding: EdgeInsets.zero,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _isRemoving ? null : _confirmRemove,
          borderRadius: BorderRadius.circular(28),
          child: SizedBox(
            height: 58,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                if (_isRemoving) ...<Widget>[
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: scheme.onErrorContainer,
                    ),
                  ),
                  const SizedBox(width: 10),
                ] else ...<Widget>[
                  Icon(
                    Icons.person_remove_outlined,
                    color: scheme.onErrorContainer,
                  ),
                  const SizedBox(width: 10),
                ],
                Text(
                  _isRemoving ? 'Removing friend' : 'Remove friend',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: scheme.onErrorContainer,
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
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
