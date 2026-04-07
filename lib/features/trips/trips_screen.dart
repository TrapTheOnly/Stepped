import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../data/db/app_db.dart';
import '../../data/repositories/trips_repository.dart';
import '../../widgets/frosted_squircle.dart';
import '../../widgets/shell_scaffold_inset.dart';
import '../../widgets/stepped_top_bar.dart';
import '../social/social_state.dart';
import '../settings/app_preferences.dart';

const _addTripButtonSize = 58.0;
const _floatingButtonGap = 16.0;

class TripsScreen extends ConsumerWidget {
  const TripsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tripsAsync = ref.watch(tripsStreamProvider);
    final preferences = ref.watch(appPreferencesProvider).valueOrNull ??
        AppPreferences.defaults;
    final colorScheme = Theme.of(context).colorScheme;
    final bottomBarHeight = ShellScaffoldInset.bottomBarHeightOf(context);
    final scrollBottomPadding =
        bottomBarHeight + _addTripButtonSize + _floatingButtonGap + 20;

    return ColoredBox(
      color: colorScheme.surface,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          const Positioned.fill(
            child: IgnorePointer(
              child: _TripsAtmosphere(),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: SteppedTopBar(
                    onOpenSettings: () => context.push('/profile/settings'),
                    onOpenProfile: () => context.push('/profile'),
                  ),
                ),
                const SizedBox(height: 18),
                Expanded(
                  child: tripsAsync.when(
                    loading: () => _TripsScrollView(
                      bottomPadding: scrollBottomPadding,
                      children: const <Widget>[
                        _TripsHorizontalPadding(
                          child: _TripsHeader(),
                        ),
                        SizedBox(height: 28),
                        _TripsHorizontalPadding(
                          child: _TripsStatusCard(
                            title: 'Loading your field journal',
                            message: 'Gathering the latest trips and imagery.',
                            showProgress: true,
                          ),
                        ),
                      ],
                    ),
                    error: (error, _) => _TripsScrollView(
                      bottomPadding: scrollBottomPadding,
                      children: <Widget>[
                        const _TripsHorizontalPadding(
                          child: _TripsHeader(),
                        ),
                        const SizedBox(height: 28),
                        _TripsHorizontalPadding(
                          child: _TripsStatusCard(
                            title: 'Trips unavailable',
                            message: 'Failed to load trips: $error',
                          ),
                        ),
                      ],
                    ),
                    data: (trips) {
                      if (trips.isEmpty) {
                        return _TripsScrollView(
                          bottomPadding: scrollBottomPadding,
                          children: const <Widget>[
                            _TripsHorizontalPadding(
                              child: _TripsHeader(),
                            ),
                            SizedBox(height: 28),
                            _TripsHorizontalPadding(
                              child: _TripsStatusCard(
                                title: 'No journeys yet',
                                message:
                                    'Start your first trip to build a stitched travel journal.',
                              ),
                            ),
                          ],
                        );
                      }

                      return _TripsScrollView(
                        bottomPadding: scrollBottomPadding,
                        children: <Widget>[
                          const _TripsHorizontalPadding(
                            child: _TripsHeader(),
                          ),
                          const SizedBox(height: 28),
                          for (final trip in trips) ...<Widget>[
                            _TripsHorizontalPadding(
                              child: _TripStoryCard(
                                trip: trip,
                                onOpen: () =>
                                    context.push('/trips/view/${trip.id}'),
                                onEdit: () =>
                                    context.push('/trips/edit/${trip.id}'),
                                onDelete: () => _confirmDelete(
                                  context,
                                  ref,
                                  trip,
                                  requireConfirmation:
                                      preferences.confirmTripDelete,
                                ),
                              ),
                            ),
                            const SizedBox(height: 18),
                          ],
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          Align(
            alignment: Alignment.bottomRight,
            child: Padding(
              padding: EdgeInsets.only(
                right: 24,
                bottom: bottomBarHeight + _floatingButtonGap,
              ),
              child: _AddTripButton(
                onTap: () => context.push('/trips/add'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    TripRecord trip, {
    required bool requireConfirmation,
  }) async {
    if (requireConfirmation) {
      final shouldDelete = await showDialog<bool>(
            context: context,
            builder: (dialogContext) {
              return AlertDialog(
                title: const Text('Delete trip?'),
                content:
                    Text('Remove ${trip.countryName} from your trips list.'),
                actions: <Widget>[
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(false),
                    child: const Text('Cancel'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.of(dialogContext).pop(true),
                    child: const Text('Delete'),
                  ),
                ],
              );
            },
          ) ??
          false;

      if (!shouldDelete) {
        return;
      }
    }

    final tripId = trip.id;
    if (tripId == null) return;
    await ref.read(tripsRepositoryProvider).deleteTrip(tripId);
    await ref.read(socialSyncControllerProvider).flushTravelNow();
  }
}

class _TripsAtmosphere extends StatelessWidget {
  const _TripsAtmosphere();

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

class _TripsScrollView extends StatelessWidget {
  const _TripsScrollView({
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

class _TripsHeader extends StatelessWidget {
  const _TripsHeader();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        'Trips',
        style: textTheme.displayMedium?.copyWith(
          fontSize: 42,
          height: 1.04,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _TripsHorizontalPadding extends StatelessWidget {
  const _TripsHorizontalPadding({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: child,
    );
  }
}

class _TripsStatusCard extends StatelessWidget {
  const _TripsStatusCard({
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
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium,
          ),
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

class _TripStoryCard extends StatelessWidget {
  const _TripStoryCard({
    required this.trip,
    required this.onOpen,
    required this.onEdit,
    required this.onDelete,
  });

  final TripRecord trip;
  final VoidCallback onOpen;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final borderRadius = BorderRadius.circular(30);

    return Semantics(
      label: 'Trip to ${trip.countryName}',
      button: true,
      child: DecoratedBox(
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
              onTap: onOpen,
              onLongPress: () => _showActionsSheet(context),
              splashFactory: NoSplash.splashFactory,
              highlightColor: Colors.transparent,
              overlayColor: WidgetStateProperty.resolveWith<Color?>(
                (states) => states.contains(WidgetState.pressed)
                    ? Colors.white.withValues(alpha: 0.06)
                    : null,
              ),
              child: SizedBox(
                height: 208,
                child: Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    _TripArtwork(
                      uri: trip.coverImageUri,
                    ),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: <Color>[
                            Colors.black.withValues(alpha: 0.1),
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.68),
                          ],
                          stops: const <double>[0, 0.36, 1],
                        ),
                      ),
                    ),
                    Positioned(
                      top: 14,
                      right: 14,
                      child: _TripCardMenu(
                        onOpen: onOpen,
                        onEdit: onEdit,
                        onDelete: onDelete,
                      ),
                    ),
                    Positioned(
                      left: 18,
                      right: 18,
                      bottom: 18,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: <Widget>[
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                _TripBadge(label: _tripBadgeLabel(trip)),
                                const SizedBox(height: 10),
                                Text(
                                  trip.countryName,
                                  style: textTheme.displaySmall?.copyWith(
                                    color: Colors.white,
                                    fontSize: 36,
                                    height: 0.96,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  _tripDateLabel(trip),
                                  style: textTheme.bodyMedium?.copyWith(
                                    color: Colors.white.withValues(alpha: 0.86),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Icon(
                            Icons.arrow_forward_ios_rounded,
                            color: Colors.white.withValues(alpha: 0.84),
                            size: 18,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showActionsSheet(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      elevation: 0,
      showDragHandle: false,
      builder: (sheetContext) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: _TripActionsSheet(
              onOpen: () {
                Navigator.of(sheetContext).pop();
                onOpen();
              },
              onEdit: () {
                Navigator.of(sheetContext).pop();
                onEdit();
              },
              onDelete: () {
                Navigator.of(sheetContext).pop();
                onDelete();
              },
            ),
          ),
        );
      },
    );
  }
}

class _TripCardMenu extends StatelessWidget {
  const _TripCardMenu({
    required this.onOpen,
    required this.onEdit,
    required this.onDelete,
  });

  final VoidCallback onOpen;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.2),
        shape: BoxShape.circle,
      ),
      child: IconButton(
        tooltip: 'Trip actions',
        onPressed: () => _showActionsSheet(context),
        icon: const Icon(
          Icons.more_horiz_rounded,
          color: Colors.white,
          size: 18,
        ),
      ),
    );
  }

  Future<void> _showActionsSheet(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      elevation: 0,
      showDragHandle: false,
      builder: (sheetContext) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: _TripActionsSheet(
              onOpen: () {
                Navigator.of(sheetContext).pop();
                onOpen();
              },
              onEdit: () {
                Navigator.of(sheetContext).pop();
                onEdit();
              },
              onDelete: () {
                Navigator.of(sheetContext).pop();
                onDelete();
              },
            ),
          ),
        );
      },
    );
  }
}

class _TripActionsSheet extends StatelessWidget {
  const _TripActionsSheet({
    required this.onOpen,
    required this.onEdit,
    required this.onDelete,
  });

  final VoidCallback onOpen;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return FrostedSquircle(
      radius: 34,
      blurSigma: 20,
      color: colorScheme.surface.withValues(alpha: 0.66),
      borderColor: colorScheme.outlineVariant.withValues(alpha: 0.16),
      shadowColor: colorScheme.primary.withValues(alpha: 0.12),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      child: Material(
        color: Colors.transparent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            DecoratedBox(
              decoration: ShapeDecoration(
                color: colorScheme.outlineVariant.withValues(alpha: 0.55),
                shape: squircleShape(8),
              ),
              child: const SizedBox(width: 36, height: 4),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.visibility_outlined),
              title: const Text('View trip'),
              titleTextStyle: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
              onTap: onOpen,
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Edit trip'),
              titleTextStyle: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
              onTap: onEdit,
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('Delete trip'),
              titleTextStyle: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
              onTap: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}

class _TripBadge extends StatelessWidget {
  const _TripBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.92),
        shape: squircleShape(12),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: Text(
          label.toUpperCase(),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Colors.white,
                fontSize: 10,
                letterSpacing: 1.3,
              ),
        ),
      ),
    );
  }
}

class _TripArtwork extends StatelessWidget {
  const _TripArtwork({
    required this.uri,
  });

  final String? uri;

  @override
  Widget build(BuildContext context) {
    final value = uri?.trim();

    if (value == null || value.isEmpty) {
      return const _TripArtworkPlaceholder();
    }

    if (value.startsWith('http://') || value.startsWith('https://')) {
      return CachedNetworkImage(
        imageUrl: value,
        fit: BoxFit.cover,
        errorWidget: (_, __, ___) => const _TripArtworkPlaceholder(),
      );
    }

    final path =
        value.startsWith('file://') ? value.replaceFirst('file://', '') : value;
    final file = File(path);
    if (!file.existsSync()) {
      return const _TripArtworkPlaceholder();
    }

    return Image.file(
      file,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => const _TripArtworkPlaceholder(),
    );
  }
}

class _TripArtworkPlaceholder extends StatelessWidget {
  const _TripArtworkPlaceholder();

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
            colorScheme.surfaceContainer.withValues(alpha: 0.86),
            colorScheme.surfaceContainerLow.withValues(alpha: 0.96),
          ],
        ),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0.58, -0.12),
            radius: 1.24,
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

class _AddTripButton extends StatelessWidget {
  const _AddTripButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Tooltip(
      message: 'Add trip',
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

String _tripBadgeLabel(TripRecord trip) {
  final now = DateTime.now();
  final start = DateTime.fromMillisecondsSinceEpoch(trip.startDate);
  final end = DateTime.fromMillisecondsSinceEpoch(trip.endDate);

  if (now.isBefore(start)) {
    return 'Upcoming';
  }
  if (!now.isAfter(end)) {
    return 'In progress';
  }

  final daysSinceReturn = now.difference(end).inDays;
  if (daysSinceReturn <= 120) {
    return 'Recently completed';
  }

  return _seasonLabel(start);
}

String _tripDateLabel(TripRecord trip) {
  final start = DateTime.fromMillisecondsSinceEpoch(trip.startDate);
  final end = DateTime.fromMillisecondsSinceEpoch(trip.endDate);
  final sameYear = start.year == end.year;
  final startFormat = DateFormat(sameYear ? 'MMM d' : 'MMM d, y');
  final endFormat = DateFormat('MMM d, y');
  return '${startFormat.format(start)} - ${endFormat.format(end)}';
}

String _seasonLabel(DateTime date) {
  final season = switch (date.month) {
    12 || 1 || 2 => 'Winter',
    3 || 4 || 5 => 'Spring',
    6 || 7 || 8 => 'Summer',
    _ => 'Autumn',
  };
  final shortYear = (date.year % 100).toString().padLeft(2, '0');
  return "$season '$shortYear";
}
