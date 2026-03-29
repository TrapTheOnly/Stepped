import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../widgets/frosted_squircle.dart';
import '../social/social_api_client.dart';
import '../social/social_models.dart';
import '../social/social_state.dart';
import '../wishlist/widgets/wishlist_editorial_widgets.dart';

const _topClearance = 114.0;
const _bottomClearance = 36.0;

class FriendWishlistDetailScreen extends ConsumerWidget {
  const FriendWishlistDetailScreen({
    super.key,
    required this.friendUserId,
    required this.wishlistItemId,
  });

  final String friendUserId;
  final String wishlistItemId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(friendProfileProvider(friendUserId));

    return profileAsync.when(
      skipLoadingOnRefresh: true,
      skipLoadingOnReload: true,
      loading: () => const _Shell(
        body: WishlistScrollView(
          bottomPadding: _bottomClearance,
          children: <Widget>[
            SizedBox(height: _topClearance),
            WishlistHorizontalPadding(
              child: WishlistStatusCard(
                title: 'Loading wishlist idea',
                message: 'Opening the shared plan details.',
                showProgress: true,
              ),
            ),
          ],
        ),
      ),
      error: (error, _) => _Shell(
        body: WishlistScrollView(
          bottomPadding: _bottomClearance,
          children: <Widget>[
            const SizedBox(height: _topClearance),
            WishlistHorizontalPadding(
              child: WishlistStatusCard(
                title: 'Wishlist unavailable',
                message: error is SocialApiException
                    ? error.message
                    : 'We could not load this shared wishlist idea.',
              ),
            ),
          ],
        ),
      ),
      data: (profile) {
        SharedWishlistItem? item;
        for (final entry in profile.wishlistItems) {
          if (entry.id.trim() == wishlistItemId.trim()) {
            item = entry;
            break;
          }
        }

        if (item == null) {
          return const _Shell(
            body: WishlistScrollView(
              bottomPadding: _bottomClearance,
              children: <Widget>[
                SizedBox(height: _topClearance),
                WishlistHorizontalPadding(
                  child: WishlistStatusCard(
                    title: 'Wishlist idea not found',
                    message: 'This shared wishlist item is no longer available.',
                  ),
                ),
              ],
            ),
          );
        }

        return _Shell(
          body: WishlistScrollView(
            bottomPadding: _bottomClearance,
            children: <Widget>[
              const SizedBox(height: _topClearance),
              WishlistHorizontalPadding(
                child: _HeroCard(
                  item: item,
                ),
              ),
              const SizedBox(height: 18),
              WishlistHorizontalPadding(
                child: _PlanSummaryCard(
                  item: item,
                ),
              ),
              const SizedBox(height: 16),
              WishlistHorizontalPadding(
                child: _TravelDetailsCard(item: item),
              ),
              if (item.plannedCities.trim().isNotEmpty) ...<Widget>[
                const SizedBox(height: 16),
                WishlistHorizontalPadding(
                  child: _CitiesCard(item: item),
                ),
              ],
              if ((item.notes ?? '').trim().isNotEmpty) ...<Widget>[
                const SizedBox(height: 16),
                WishlistHorizontalPadding(
                  child: _NotesCard(
                    item: item,
                    friendName: profile.friend.displayName,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _Shell extends StatelessWidget {
  const _Shell({required this.body});

  final Widget body;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: ColoredBox(
        color: scheme.surface,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            const Positioned.fill(
              child: IgnorePointer(child: WishlistAtmosphere()),
            ),
            Positioned.fill(child: body),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: _TopBar(
                    onBack: () {
                      if (context.canPop()) {
                        context.pop();
                        return;
                      }
                      context.go('/friends');
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return FrostedSquircle(
      radius: 28,
      blurSigma: 16,
      color: scheme.surface.withValues(alpha: 0.58),
      borderColor: scheme.primaryContainer.withValues(alpha: 0.14),
      shadowColor: scheme.primary.withValues(alpha: 0.06),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: SizedBox(
        height: 34,
        child: Row(
          children: <Widget>[
            SizedBox(
              width: 56,
              child: Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  onPressed: onBack,
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 30, minHeight: 30),
                  icon: Icon(
                    Icons.arrow_back_ios_new_rounded,
                    size: 20,
                    color: scheme.onSurface,
                  ),
                ),
              ),
            ),
            Expanded(
              child: Text(
                'Plan',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontSize: 24,
                      height: 1,
                    ),
              ),
            ),
            const SizedBox(width: 56),
          ],
        ),
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.item,
  });

  final SharedWishlistItem item;

  @override
  Widget build(BuildContext context) {
    final duration = _durationLabel(item);
    final chips = <String>[
      if (duration != null) duration,
      if (item.plannedCities.trim().isNotEmpty)
        '${item.plannedCities.split(',').where((city) => city.trim().isNotEmpty).length} cities',
    ];
    final destination = item.countryName.trim().isNotEmpty
        ? item.countryName.trim()
        : 'Destination still being shaped';
    final imageUrl = item.imageUrl?.trim();

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
            blurRadius: 34,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: SizedBox(
          height: 304,
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              if (imageUrl != null && imageUrl.isNotEmpty)
                CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => const _HeroFallback(),
                )
              else
                const _HeroFallback(),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: <Color>[
                      Colors.black.withValues(alpha: 0.08),
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.68),
                    ],
                    stops: const <double>[0, 0.4, 1],
                  ),
                ),
              ),
              Positioned(
                left: 18,
                top: 18,
                child: _HeroPill(label: 'Wishlist idea'),
              ),
              Positioned(
                left: 20,
                right: 20,
                bottom: 22,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.displaySmall?.copyWith(
                            color: Colors.white,
                            fontSize: 36,
                            height: 0.98,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      destination,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: Colors.white.withValues(alpha: 0.86),
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    if (chips.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: chips
                            .map((label) => _HeroPill(label: label))
                            .toList(growable: false),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeroFallback extends StatelessWidget {
  const _HeroFallback();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            scheme.surfaceContainerHigh.withValues(alpha: 0.92),
            scheme.surfaceContainer.withValues(alpha: 0.86),
            scheme.surfaceContainerLow.withValues(alpha: 0.94),
          ],
        ),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0.6, -0.2),
            radius: 1.25,
            colors: <Color>[
              scheme.primary.withValues(alpha: 0.16),
              Colors.transparent,
            ],
          ),
        ),
        child: Center(
          child: Icon(
            Icons.travel_explore_rounded,
            size: 72,
            color: scheme.onSurface.withValues(alpha: 0.22),
          ),
        ),
      ),
    );
  }
}

class _HeroPill extends StatelessWidget {
  const _HeroPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        shape: const StadiumBorder(),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
        ),
      ),
    );
  }
}

class _PlanSummaryCard extends StatelessWidget {
  const _PlanSummaryCard({required this.item});

  final SharedWishlistItem item;

  @override
  Widget build(BuildContext context) {
    final notes = item.notes?.trim() ?? '';
    final cities = item.plannedCities
        .split(',')
        .map((city) => city.trim())
        .where((city) => city.isNotEmpty)
        .toList(growable: false);
    final dateLabel = _dateLabel(item);
    final summary = notes.isNotEmpty
        ? notes
        : cities.isNotEmpty
            ? 'Stops across ${cities.join(', ')}.'
            : dateLabel ?? 'A saved travel idea.';

    return _GlassSection(
      title: 'Overview',
      child: Text(
        summary,
        style: Theme.of(context).textTheme.bodyLarge,
      ),
    );
  }
}

class _TravelDetailsCard extends StatelessWidget {
  const _TravelDetailsCard({required this.item});

  final SharedWishlistItem item;

  @override
  Widget build(BuildContext context) {
    final createdLabel = item.createdAt == null
        ? null
        : DateFormat.yMMMd().format(item.createdAt!);
    final dateLabel = _dateLabel(item);
    final durationLabel = _durationLabel(item);

    return _GlassSection(
      title: 'Travel details',
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: <Widget>[
          if (dateLabel != null)
            _MetaChip(
              label: dateLabel,
              icon: Icons.schedule_rounded,
            ),
          if (durationLabel != null)
            _MetaChip(
              label: durationLabel,
              icon: Icons.timelapse_rounded,
            ),
          if (createdLabel != null)
            _MetaChip(
              label: 'Saved $createdLabel',
              icon: Icons.bookmark_added_rounded,
            ),
        ],
      ),
    );
  }
}

class _CitiesCard extends StatelessWidget {
  const _CitiesCard({required this.item});

  final SharedWishlistItem item;

  @override
  Widget build(BuildContext context) {
    final cities = item.plannedCities
        .split(',')
        .map((city) => city.trim())
        .where((city) => city.isNotEmpty)
        .toList(growable: false);

    return _GlassSection(
      title: 'Cities',
      child: cities.isEmpty
          ? Text(
              'No city list is saved yet.',
              style: Theme.of(context).textTheme.bodyMedium,
            )
          : Column(
              children: <Widget>[
                for (var index = 0; index < cities.length; index += 1) ...<Widget>[
                  _CityStopCard(
                    index: index,
                    city: cities[index],
                  ),
                  if (index != cities.length - 1) const SizedBox(height: 12),
                ],
              ],
            ),
    );
  }
}

class _NotesCard extends StatelessWidget {
  const _NotesCard({
    required this.item,
    required this.friendName,
  });

  final SharedWishlistItem item;
  final String friendName;

  @override
  Widget build(BuildContext context) {
    return _GlassSection(
      title: "$friendName's notes",
      child: Text(
        item.notes!.trim(),
        style: Theme.of(context).textTheme.bodyLarge,
      ),
    );
  }
}

class _GlassSection extends StatelessWidget {
  const _GlassSection({
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return FrostedSquircle(
      radius: 30,
      blurSigma: 18,
      color: scheme.surface.withValues(alpha: 0.74),
      borderColor: scheme.primaryContainer.withValues(alpha: 0.16),
      shadowColor: scheme.primary.withValues(alpha: 0.08),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _CityStopCard extends StatelessWidget {
  const _CityStopCard({
    required this.index,
    required this.city,
  });

  final int index;
  final String city;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: scheme.surfaceContainerLowest.withValues(alpha: 0.84),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.12),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Row(
          children: <Widget>[
            DecoratedBox(
              decoration: ShapeDecoration(
                color: scheme.primaryContainer.withValues(alpha: 0.62),
                shape: const CircleBorder(),
              ),
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Text(
                  '${index + 1}',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: scheme.onPrimaryContainer,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                city,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({
    required this.label,
    required this.icon,
  });

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: ShapeDecoration(
        color: scheme.surface.withValues(alpha: 0.72),
        shape: StadiumBorder(
          side: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.14),
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 14, color: scheme.onSurfaceVariant),
            const SizedBox(width: 6),
            Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: scheme.onSurface,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

String? _dateLabel(SharedWishlistItem item) {
  final formatter = DateFormat('MMM d, y');
  final start = item.plannedStartDate == null
      ? null
      : DateTime.fromMillisecondsSinceEpoch(item.plannedStartDate!);
  final end = item.plannedEndDate == null
      ? null
      : DateTime.fromMillisecondsSinceEpoch(item.plannedEndDate!);
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

String? _durationLabel(SharedWishlistItem item) {
  final start = item.plannedStartDate;
  final end = item.plannedEndDate;
  if (start == null || end == null) {
    return null;
  }
  final startDate = DateTime.fromMillisecondsSinceEpoch(start);
  final endDate = DateTime.fromMillisecondsSinceEpoch(end);
  final days = endDate.difference(startDate).inDays + 1;
  if (days <= 0) {
    return null;
  }
  return '$days ${days == 1 ? 'day' : 'days'}';
}
