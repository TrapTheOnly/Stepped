import 'dart:convert';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../data/db/app_db.dart';
import '../../../widgets/frosted_squircle.dart';

class WishlistReadinessStep {
  const WishlistReadinessStep({
    required this.label,
    required this.points,
    required this.completed,
  });

  final String label;
  final int points;
  final bool completed;
}

class WishlistReadinessSnapshot {
  const WishlistReadinessSnapshot({
    required this.score,
    required this.steps,
  });

  final int score;
  final List<WishlistReadinessStep> steps;

  List<WishlistReadinessStep> get remainingSteps =>
      steps.where((step) => !step.completed).toList(growable: false);
}

class WishlistAtmosphere extends StatelessWidget {
  const WishlistAtmosphere({super.key});

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
    );
  }
}

class WishlistScrollView extends StatelessWidget {
  const WishlistScrollView({
    super.key,
    required this.children,
    required this.bottomPadding,
  });

  final List<Widget> children;
  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.fromLTRB(0, 0, 0, bottomPadding),
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

class WishlistHorizontalPadding extends StatelessWidget {
  const WishlistHorizontalPadding({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: child,
    );
  }
}

class WishlistHeader extends StatelessWidget {
  const WishlistHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        'Wishlist',
        style: Theme.of(context).textTheme.displayMedium?.copyWith(
              fontSize: 42,
              height: 1.04,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

class WishlistStatusCard extends StatelessWidget {
  const WishlistStatusCard({
    super.key,
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
      color: colorScheme.surface.withValues(alpha: 0.74),
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

class WishlistEmptyState extends StatelessWidget {
  const WishlistEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return FrostedSquircle(
      radius: 34,
      blurSigma: 20,
      color: colorScheme.surface.withValues(alpha: 0.78),
      borderColor: colorScheme.primaryContainer.withValues(alpha: 0.16),
      shadowColor: colorScheme.primary.withValues(alpha: 0.08),
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          DecoratedBox(
            decoration: ShapeDecoration(
              color: colorScheme.secondaryContainer.withValues(alpha: 0.62),
              shape: squircleShape(20),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Icon(
                Icons.push_pin_outlined,
                color: colorScheme.onSecondaryContainer,
                size: 22,
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'No places saved yet',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'Use Add idea to start collecting the destinations you want to turn into trips.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }
}

class WishlistStoryCard extends StatelessWidget {
  const WishlistStoryCard({
    super.key,
    required this.item,
    required this.countryCode,
    required this.showDate,
    required this.dateFormat,
    required this.onPinToggle,
    required this.onActions,
    this.onOpenPlan,
  });

  final WishlistItemRecord item;
  final String? countryCode;
  final bool showDate;
  final DateFormat dateFormat;
  final VoidCallback? onOpenPlan;
  final VoidCallback onPinToggle;
  final VoidCallback onActions;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final readiness = _wishlistReadiness(item);

    return Semantics(
      label: 'Wishlist item ${item.title}',
      hint: onOpenPlan == null
          ? 'Long press for actions.'
          : 'Double tap to open the plan. Long press for actions.',
      button: onOpenPlan != null,
      child: DecoratedBox(
        decoration: BoxDecoration(
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: colorScheme.primary.withValues(alpha: 0.08),
              blurRadius: 32,
              offset: const Offset(0, 18),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onOpenPlan,
            onLongPress: onActions,
            splashFactory: NoSplash.splashFactory,
            highlightColor: Colors.transparent,
            overlayColor: WidgetStateProperty.resolveWith<Color?>(
              (states) => states.contains(WidgetState.pressed)
                  ? Colors.white.withValues(alpha: 0.06)
                  : null,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(30),
                    topRight: Radius.circular(30),
                  ),
                  child: Stack(
                    fit: StackFit.passthrough,
                    children: <Widget>[
                      SizedBox(
                        height: 208,
                        width: double.infinity,
                        child: _WishlistHeroArtwork(
                          item: item,
                          countryCode: countryCode,
                        ),
                      ),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: <Color>[
                              Colors.black.withValues(alpha: 0.06),
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.6),
                            ],
                            stops: const <double>[0, 0.42, 1],
                          ),
                        ),
                      ),
                      Positioned(
                        top: 14,
                        left: 14,
                        right: 14,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: <Widget>[
                            _WishlistPinButton(
                              isPinned: item.isPinned,
                              onTap: onPinToggle,
                            ),
                            _WishlistCardMenuButton(
                              onTap: onActions,
                            ),
                          ],
                        ),
                      ),
                      Positioned(
                        left: 18,
                        right: 18,
                        bottom: 18,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            if (item.isPinned) ...<Widget>[
                              _WishlistFeaturedPill(
                                colorScheme: colorScheme,
                              ),
                              const SizedBox(height: 10),
                            ],
                            Text(
                              _wishlistHeroTitle(item),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
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
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              _wishlistSavedLabel(
                                item,
                                dateFormat,
                                showDate,
                              ),
                              style: Theme.of(context)
                                  .textTheme
                                  .labelMedium
                                  ?.copyWith(
                                    color: colorScheme.secondary,
                                    letterSpacing: 0.35,
                                  ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          _WishlistReadinessPill(readiness: readiness),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              _wishlistCountryLabel(item),
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    color: colorScheme.onSurface,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            _wishlistDurationLabel(item, dateFormat),
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WishlistFeaturedPill extends StatelessWidget {
  const _WishlistFeaturedPill({required this.colorScheme});

  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: colorScheme.secondaryContainer.withValues(alpha: 0.92),
        shape: squircleShape(14),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Text(
          'FEATURED',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: colorScheme.onSecondaryContainer,
                fontSize: 10,
                letterSpacing: 1.4,
              ),
        ),
      ),
    );
  }
}

class _WishlistPinButton extends StatelessWidget {
  const _WishlistPinButton({
    required this.isPinned,
    required this.onTap,
  });

  final bool isPinned;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Tooltip(
      message: isPinned ? 'Remove from top' : 'Pin to top',
      child: Material(
        color: colorScheme.surface.withValues(alpha: 0.76),
        shape: const CircleBorder(),
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Icon(
              isPinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
              size: 19,
              color: isPinned
                  ? colorScheme.primary
                  : colorScheme.onSurface.withValues(alpha: 0.88),
            ),
          ),
        ),
      ),
    );
  }
}

class _WishlistCardMenuButton extends StatelessWidget {
  const _WishlistCardMenuButton({
    required this.onTap,
  });

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.2),
        shape: BoxShape.circle,
      ),
      child: IconButton(
        tooltip: 'Wishlist actions',
        onPressed: onTap,
        icon: const Icon(
          Icons.more_horiz_rounded,
          color: Colors.white,
          size: 18,
        ),
      ),
    );
  }
}

class _WishlistReadinessPill extends StatelessWidget {
  const _WishlistReadinessPill({required this.readiness});

  final int readiness;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: ShapeDecoration(
        color: colorScheme.surfaceContainerHigh,
        shape: squircleShape(16),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(
          '$readiness% ready',
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: colorScheme.onSurface,
                fontSize: 11,
                letterSpacing: 0.4,
              ),
        ),
      ),
    );
  }
}

class _WishlistHeroArtwork extends StatelessWidget {
  const _WishlistHeroArtwork({
    required this.item,
    required this.countryCode,
  });

  final WishlistItemRecord item;
  final String? countryCode;

  @override
  Widget build(BuildContext context) {
    final imageUrl = wishlistPrimaryImageUrl(item);

    if (imageUrl == null) {
      return const _WishlistHeroPlaceholder();
    }

    if (!imageUrl.startsWith('http://') && !imageUrl.startsWith('https://')) {
      final localPath = imageUrl.startsWith('file://')
          ? imageUrl.replaceFirst('file://', '')
          : imageUrl;
      final file = File(localPath);
      if (file.existsSync()) {
        return Image.file(
          file,
          fit: BoxFit.cover,
          alignment: Alignment.topCenter,
        );
      }
      return const _WishlistHeroPlaceholder();
    }

    return CachedNetworkImage(
      imageUrl: imageUrl,
      fit: BoxFit.cover,
      alignment: Alignment.topCenter,
      placeholder: (_, __) => const _WishlistHeroPlaceholder(),
      errorWidget: (_, __, ___) => const _WishlistHeroPlaceholder(),
    );
  }
}

class _WishlistHeroPlaceholder extends StatelessWidget {
  const _WishlistHeroPlaceholder();

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
      ),
    );
  }
}

class WishlistAddIdeaButton extends StatelessWidget {
  const WishlistAddIdeaButton({
    super.key,
    required this.onTap,
  });

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Tooltip(
      message: 'Add idea',
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: colorScheme.primary.withValues(alpha: 0.18),
              blurRadius: 28,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: ClipOval(
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              customBorder: const CircleBorder(),
              splashFactory: NoSplash.splashFactory,
              highlightColor: Colors.transparent,
              overlayColor: WidgetStateProperty.resolveWith<Color?>(
                (states) => states.contains(WidgetState.pressed)
                    ? Colors.white.withValues(alpha: 0.08)
                    : null,
              ),
              child: Ink(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: <Color>[
                      colorScheme.primary,
                      colorScheme.primaryContainer,
                    ],
                  ),
                ),
                child: Icon(
                  Icons.add_rounded,
                  color: colorScheme.onPrimary,
                  size: 28,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String _wishlistHeroTitle(WishlistItemRecord item) {
  final title = item.title.trim();
  if (title.isNotEmpty) {
    return title;
  }
  final country = item.countryName?.trim();
  if (country != null && country.isNotEmpty) {
    return country;
  }
  return 'Untitled idea';
}

String _wishlistSavedLabel(
  WishlistItemRecord item,
  DateFormat dateFormat,
  bool showDate,
) {
  if (showDate) {
    return 'Saved ${dateFormat.format(DateTime.fromMillisecondsSinceEpoch(item.createdAt))}';
  }

  final startMillis = item.plannedStartDate;
  final endMillis = item.plannedEndDate;
  if (startMillis != null && endMillis != null) {
    final start = DateTime.fromMillisecondsSinceEpoch(startMillis);
    final end = DateTime.fromMillisecondsSinceEpoch(endMillis);
    return '${DateFormat('MMM d').format(start)} - ${dateFormat.format(end)}';
  }

  return 'Saved recently';
}

String _wishlistCountryLabel(WishlistItemRecord item) {
  final country = item.countryName?.trim();
  if (country != null && country.isNotEmpty) {
    return country;
  }
  return 'Country not set';
}

String _wishlistDurationLabel(
  WishlistItemRecord item,
  DateFormat dateFormat,
) {
  final startMillis = item.plannedStartDate;
  final endMillis = item.plannedEndDate;
  if (startMillis == null || endMillis == null) {
    final aiDurationDays = _wishlistAiDurationDays(item);
    if (aiDurationDays != null) {
      return '$aiDurationDays ${aiDurationDays == 1 ? 'day' : 'days'}';
    }
    return 'Set dates';
  }

  final start = DateTime.fromMillisecondsSinceEpoch(startMillis);
  final end = DateTime.fromMillisecondsSinceEpoch(endMillis);
  final tripLength = end.difference(start).inDays + 1;
  if (tripLength > 0) {
    return '$tripLength ${tripLength == 1 ? 'day' : 'days'}';
  }

  if (start.year == end.year) {
    return '${DateFormat('MMM d').format(start)} - ${DateFormat('MMM d').format(end)}';
  }

  return '${dateFormat.format(start)} - ${dateFormat.format(end)}';
}

int _wishlistReadiness(WishlistItemRecord item) {
  return wishlistReadinessSnapshot(item).score;
}

WishlistReadinessSnapshot wishlistReadinessSnapshot(
  WishlistItemRecord item,
) {
  const baseScore = 10;
  final steps = <WishlistReadinessStep>[
    WishlistReadinessStep(
      label: 'Name the trip idea',
      points: 15,
      completed: item.title.trim().isNotEmpty,
    ),
    WishlistReadinessStep(
      label: 'Choose the destination country',
      points: 30,
      completed: (item.countryName ?? '').trim().isNotEmpty,
    ),
    WishlistReadinessStep(
      label: 'Save an itinerary draft',
      points: 20,
      completed: _wishlistHasSavedItinerary(item),
    ),
    WishlistReadinessStep(
      label: 'Set exact travel dates',
      points: 25,
      completed: item.plannedStartDate != null && item.plannedEndDate != null,
    ),
  ];

  final score = steps.fold<int>(
    baseScore,
    (total, step) => step.completed ? total + step.points : total,
  );

  return WishlistReadinessSnapshot(
    score: score.clamp(baseScore, 100),
    steps: List<WishlistReadinessStep>.unmodifiable(steps),
  );
}

int? _wishlistAiDurationDays(WishlistItemRecord item) {
  final rawPlan = item.aiPlan?.trim();
  if (rawPlan == null || rawPlan.isEmpty) {
    return null;
  }

  try {
    final decoded = jsonDecode(rawPlan);
    if (decoded is! Map<String, dynamic>) {
      return null;
    }
    final duration = decoded['duration'];
    if (duration is! Map<String, dynamic>) {
      return null;
    }
    final days = duration['days'];
    if (days is int && days > 0) {
      return days;
    }
    if (days is num && days > 0) {
      return days.toInt();
    }
  } catch (_) {
    return null;
  }

  return null;
}

String? wishlistPrimaryImageUrl(WishlistItemRecord item) {
  final rawPlan = item.aiPlan?.trim();
  if (rawPlan == null || rawPlan.isEmpty) {
    return null;
  }

  try {
    final decoded = jsonDecode(rawPlan);
    if (decoded is! Map<String, dynamic>) {
      return null;
    }
    final coverImage = decoded['cover_image'];
    if (coverImage is Map<String, dynamic>) {
      final imageUrl = coverImage['image_url'];
      if (imageUrl is String && imageUrl.trim().isNotEmpty) {
        return imageUrl.trim();
      }
    }
    final cityCards = decoded['city_cards'];
    if (cityCards is! List) {
      return null;
    }
    for (final card in cityCards) {
      if (card is! Map<String, dynamic>) {
        continue;
      }
      final image = card['image'];
      if (image is! Map<String, dynamic>) {
        continue;
      }
      final imageUrl = image['image_url'];
      if (imageUrl is String && imageUrl.trim().isNotEmpty) {
        return imageUrl.trim();
      }
    }
  } catch (_) {
    return null;
  }

  return null;
}

bool _wishlistHasSavedItinerary(WishlistItemRecord item) {
  final rawPlan = item.aiPlan?.trim();
  if (rawPlan == null || rawPlan.isEmpty) {
    return false;
  }

  try {
    final decoded = jsonDecode(rawPlan);
    if (decoded is! Map<String, dynamic>) {
      return false;
    }
    final summary = decoded['summary'];
    if (summary is String && summary.trim().isNotEmpty) {
      return true;
    }
    final duration = decoded['duration'];
    if (duration is Map<String, dynamic>) {
      final days = duration['days'];
      if (days is int && days > 0) {
        return true;
      }
      if (days is num && days > 0) {
        return true;
      }
    }
    final timeWindows = decoded['time_windows'];
    if (timeWindows is List && timeWindows.isNotEmpty) {
      return true;
    }
    final cityPlan = decoded['city_plan'];
    if (cityPlan is List && cityPlan.isNotEmpty) {
      return true;
    }
    final cityCards = decoded['city_cards'];
    if (cityCards is List && cityCards.isNotEmpty) {
      return true;
    }
  } catch (_) {
    return false;
  }

  return false;
}
