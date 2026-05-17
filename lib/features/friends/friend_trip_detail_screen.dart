import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../widgets/editorial_overlay_page_shell.dart';
import '../../widgets/frosted_squircle.dart';
import '../social/social_api_client.dart';
import '../social/social_models.dart';
import '../social/social_state.dart';
import '../trips/trip_city_detail_screen.dart';
import '../trips/trip_city_models.dart';
import '../trips/widgets/add_trip_cover_image_preview.dart';
import '../trips/widgets/add_trip_destination_preview.dart';
import '../trips/widgets/add_trip_form_sections.dart';

const _friendTripBottomPadding = 48.0;

class FriendTripDetailScreen extends ConsumerWidget {
  const FriendTripDetailScreen({
    super.key,
    required this.friendUserId,
    required this.tripId,
  });

  final String friendUserId;
  final String tripId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(friendProfileProvider(friendUserId));
    final colorScheme = Theme.of(context).colorScheme;

    return EditorialOverlayPageShell(
      background: const _FriendTripAtmosphere(),
      backgroundColor: colorScheme.surface,
      topBar: _FriendTripTopBar(
        onBack: () => _popOrGoToProfile(context),
      ),
      bodyBuilder: (context, topContentInset, __) {
        return profileAsync.when(
          loading: () => const _StatusView(
            title: 'Opening trip',
            message: 'Loading the shared route and city guides.',
            showProgress: true,
          ),
          error: (error, _) => _StatusView(
            title: 'Trip unavailable',
            message: _messageForError(error),
          ),
          data: (profile) {
            final trip = _findTrip(profile.trips);
            if (trip == null) {
              return const _StatusView(
                title: 'Trip unavailable',
                message:
                    'This shared trip could not be found in the current friend profile response.',
              );
            }

            return _FriendTripScrollView(
              topPadding: topContentInset,
              children: <Widget>[
                _FriendHorizontalPadding(
                  child: AddTripDestinationPreview(
                    countryCode: trip.countryCode,
                    countryName: trip.countryName,
                    coverImageUri: trip.coverImageUrl,
                    startDate: DateTime.fromMillisecondsSinceEpoch(
                      trip.startDate,
                    ),
                    endDate: DateTime.fromMillisecondsSinceEpoch(
                      trip.endDate,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                _FriendHorizontalPadding(
                  child: _ReadOnlyDestinationSection(trip: trip),
                ),
                const SizedBox(height: 12),
                _FriendHorizontalPadding(
                  child: _ReadOnlyTravelDetailsSection(
                    trip: trip,
                    onOpenCity: (city) => _openCity(
                      context,
                      city: city,
                      countryName: trip.countryName,
                      ownerDisplayName: profile.friend.displayName,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _FriendHorizontalPadding(
                  child: _ReadOnlyMediaNotesSection(trip: trip),
                ),
              ],
            );
          },
        );
      },
    );
  }

  SocialTripSummary? _findTrip(List<SocialTripSummary> trips) {
    final normalizedId = tripId.trim();
    for (final trip in trips) {
      if (_tripRouteId(trip) == normalizedId) {
        return trip;
      }
    }
    return null;
  }

  String _messageForError(Object error) {
    if (error is SocialApiException) {
      return error.message;
    }
    return 'We could not load this shared trip right now.';
  }

  void _openCity(
    BuildContext context, {
    required TripCityEntry city,
    required String countryName,
    required String ownerDisplayName,
  }) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => TripCityDetailScreen(
          city: city,
          countryName: countryName,
          mode: TripCityScreenMode.view,
          allowEditing: false,
          ownerDisplayName: ownerDisplayName,
        ),
      ),
    );
  }

  void _popOrGoToProfile(BuildContext context) {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go('/friends/profile/$friendUserId');
  }
}

class _FriendTripAtmosphere extends StatelessWidget {
  const _FriendTripAtmosphere();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            scheme.surface.withValues(alpha: 0.08),
            scheme.surface,
          ],
        ),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0.85, -0.7),
            radius: 1.0,
            colors: <Color>[
              scheme.secondary.withValues(alpha: 0.12),
              Colors.transparent,
            ],
          ),
        ),
      ),
    );
  }
}

class _FriendTripTopBar extends StatelessWidget {
  const _FriendTripTopBar({required this.onBack});

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
              width: 84,
              child: Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  onPressed: onBack,
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 30, minHeight: 30),
                  visualDensity: VisualDensity.compact,
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
                'Trip',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontSize: 24,
                      height: 1,
                    ),
              ),
            ),
            const SizedBox(width: 84),
          ],
        ),
      ),
    );
  }
}

class _FriendTripScrollView extends StatelessWidget {
  const _FriendTripScrollView({
    required this.children,
    this.topPadding = 0,
  });

  final List<Widget> children;
  final double topPadding;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        0,
        topPadding,
        0,
        _friendTripBottomPadding,
      ),
      children: children,
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

class _ReadOnlyDestinationSection extends StatelessWidget {
  const _ReadOnlyDestinationSection({required this.trip});

  final SocialTripSummary trip;

  @override
  Widget build(BuildContext context) {
    return _TripSectionShell(
      title: 'Destination',
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          color: Theme.of(context)
              .colorScheme
              .surfaceContainerHighest
              .withValues(alpha: 0.44),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Row(
            children: <Widget>[
              DecoratedBox(
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .primaryContainer
                      .withValues(alpha: 0.24),
                  shape: BoxShape.circle,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Icon(
                    Icons.public_rounded,
                    size: 18,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      trip.countryName,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      trip.countryCode.toUpperCase(),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
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

class _ReadOnlyTravelDetailsSection extends StatelessWidget {
  const _ReadOnlyTravelDetailsSection({
    required this.trip,
    required this.onOpenCity,
  });

  final SocialTripSummary trip;
  final ValueChanged<TripCityEntry> onOpenCity;

  @override
  Widget build(BuildContext context) {
    final cities = _tripCities(trip);

    return _TripSectionShell(
      title: 'Travel Details',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _ReadOnlyTripDates(
            startDate: DateTime.fromMillisecondsSinceEpoch(trip.startDate),
            endDate: DateTime.fromMillisecondsSinceEpoch(trip.endDate),
          ),
          const SizedBox(height: 16),
          if (cities.isEmpty)
            Text(
              'No city guides have been shared for this trip yet.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            )
          else
            Column(
              children: cities
                  .map(
                    (city) => Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: TripCityRouteCard(
                        city: city,
                        inheritedPlan: null,
                        inheritedDetail: null,
                        onOpen: () => onOpenCity(city),
                        showRemoveAction: false,
                        showOpenGuideChip: false,
                        fallbackRouteReason: null,
                      ),
                    ),
                  )
                  .toList(growable: false),
            ),
        ],
      ),
    );
  }
}

class _ReadOnlyMediaNotesSection extends StatelessWidget {
  const _ReadOnlyMediaNotesSection({required this.trip});

  final SocialTripSummary trip;

  @override
  Widget build(BuildContext context) {
    final normalizedCover = trip.coverImageUrl?.trim() ?? '';
    final normalizedNotes = trip.notes?.trim() ?? '';

    return _TripSectionShell(
      title: 'Media & Notes',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Cover image',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 12),
          if (normalizedCover.isNotEmpty)
            AddTripCoverImagePreview(uri: normalizedCover)
          else
            Text(
              'No cover image was shared for this trip.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          const SizedBox(height: 16),
          Text(
            'Notes',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          Text(
            normalizedNotes.isEmpty
                ? 'No trip notes were shared yet.'
                : normalizedNotes,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  height: 1.4,
                  color: normalizedNotes.isEmpty
                      ? Theme.of(context).colorScheme.onSurfaceVariant
                      : null,
                ),
          ),
        ],
      ),
    );
  }
}

class _ReadOnlyTripDates extends StatelessWidget {
  const _ReadOnlyTripDates({
    required this.startDate,
    required this.endDate,
  });

  final DateTime startDate;
  final DateTime endDate;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: _ReadOnlyTripDateCard(
            label: 'Start date',
            value: startDate,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _ReadOnlyTripDateCard(
            label: 'End date',
            value: endDate,
          ),
        ),
      ],
    );
  }
}

class _ReadOnlyTripDateCard extends StatelessWidget {
  const _ReadOnlyTripDateCard({
    required this.label,
    required this.value,
  });

  final String label;
  final DateTime value;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final monthDay = DateFormat('MMM d').format(value);
    final year = DateFormat('y').format(value);

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.44),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(
          children: <Widget>[
            DecoratedBox(
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer.withValues(alpha: 0.24),
                shape: BoxShape.circle,
              ),
              child: Padding(
                padding: const EdgeInsets.all(7),
                child: Icon(
                  Icons.calendar_month_rounded,
                  size: 16,
                  color: colorScheme.primary,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    label,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    monthDay,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  Text(
                    year,
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

class _TripSectionShell extends StatelessWidget {
  const _TripSectionShell({
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return FrostedSquircle(
      radius: 30,
      blurSigma: 16,
      color: colorScheme.surface.withValues(alpha: 0.72),
      borderColor: colorScheme.primaryContainer.withValues(alpha: 0.14),
      shadowColor: colorScheme.primary.withValues(alpha: 0.08),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _StatusView extends StatelessWidget {
  const _StatusView({
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
    final topPadding = editorialOverlayTopContentInsetOf(context, fallback: 24);

    return Padding(
      padding: EdgeInsets.fromLTRB(16, topPadding, 16, 16),
      child: Center(
        child: FrostedSquircle(
          radius: 30,
          blurSigma: 16,
          color: colorScheme.surface.withValues(alpha: 0.72),
          borderColor: colorScheme.primaryContainer.withValues(alpha: 0.14),
          shadowColor: colorScheme.primary.withValues(alpha: 0.08),
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
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
        ),
      ),
    );
  }
}

List<TripCityEntry> _tripCities(SocialTripSummary trip) {
  if (trip.cityEntries.isNotEmpty) {
    return trip.cityEntries;
  }
  return parseTripCityNames(trip.cities)
      .map((name) => TripCityEntry(name: name))
      .toList(growable: false);
}

String _tripRouteId(SocialTripSummary trip) {
  final normalizedId = trip.id.trim();
  if (normalizedId.isNotEmpty) {
    return normalizedId;
  }
  return '${trip.countryCode}-${trip.startDate}-${trip.endDate}';
}
