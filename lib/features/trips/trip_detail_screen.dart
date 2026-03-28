import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../data/db/app_db.dart';
import '../../data/repositories/trips_repository.dart';
import '../../data/repositories/wishlist_repository.dart';
import '../../widgets/frosted_squircle.dart';
import '../wishlist/gemini_trip_planner.dart';
import '../wishlist/widgets/wishlist_editorial_widgets.dart';
import 'trip_city_detail_screen.dart';
import 'trip_city_models.dart';
import 'widgets/add_trip_destination_preview.dart';
import 'widgets/add_trip_form_sections.dart';

const _tripDetailTopClearance = 114.0;
const _tripDetailBottomClearance = 44.0;

class TripDetailScreen extends ConsumerStatefulWidget {
  const TripDetailScreen({
    super.key,
    required this.tripId,
  });

  final int tripId;

  @override
  ConsumerState<TripDetailScreen> createState() => _TripDetailScreenState();
}

class _TripDetailScreenState extends ConsumerState<TripDetailScreen> {
  TripRecord? _trip;
  List<TripCityEntry> _tripCities = const <TripCityEntry>[];
  String? _tripFingerprint;

  @override
  Widget build(BuildContext context) {
    final tripAsync = ref.watch(tripByIdProvider(widget.tripId));
    final sourceWishlistItemId = _trip?.sourceWishlistItemId ??
        tripAsync.valueOrNull?.sourceWishlistItemId;
    final wishlistItemAsync = sourceWishlistItemId == null
        ? const AsyncValue<WishlistItemRecord?>.data(null)
        : ref.watch(wishlistItemProvider(sourceWishlistItemId));

    return tripAsync.when(
      loading: () => const _TripDetailShell(
        title: 'Trip',
        body: WishlistScrollView(
          bottomPadding: _tripDetailBottomClearance,
          children: <Widget>[
            SizedBox(height: _tripDetailTopClearance),
            WishlistHorizontalPadding(
              child: WishlistStatusCard(
                title: 'Loading trip',
                message: 'Pulling together the route details for this journal.',
                showProgress: true,
              ),
            ),
          ],
        ),
      ),
      error: (error, _) => _TripDetailShell(
        title: 'Trip',
        body: WishlistScrollView(
          bottomPadding: _tripDetailBottomClearance,
          children: <Widget>[
            const SizedBox(height: _tripDetailTopClearance),
            WishlistHorizontalPadding(
              child: WishlistStatusCard(
                title: 'Trip unavailable',
                message: 'Failed to load this trip: $error',
              ),
            ),
          ],
        ),
      ),
      data: (trip) {
        if (trip == null) {
          return const _TripDetailShell(
            title: 'Trip',
            body: WishlistScrollView(
              bottomPadding: _tripDetailBottomClearance,
              children: <Widget>[
                SizedBox(height: _tripDetailTopClearance),
                WishlistHorizontalPadding(
                  child: WishlistStatusCard(
                    title: 'Trip unavailable',
                    message: 'This trip is no longer available.',
                  ),
                ),
              ],
            ),
          );
        }

        _hydrateFromTrip(trip);

        final planner = ref.read(geminiTripPlannerProvider);
        final inheritance = buildTripWishlistInheritance(
          item: wishlistItemAsync.valueOrNull,
          planner: planner,
        );
        final startDate =
            DateTime.fromMillisecondsSinceEpoch(_trip!.startDate);
        final endDate = DateTime.fromMillisecondsSinceEpoch(_trip!.endDate);

        return _TripDetailShell(
          title: 'Trip',
          onEdit: _openEditor,
          body: WishlistScrollView(
            bottomPadding: _tripDetailBottomClearance,
            children: <Widget>[
              const SizedBox(height: _tripDetailTopClearance),
              WishlistHorizontalPadding(
                child: AddTripDestinationPreview(
                  countryCode: _trip!.countryCode,
                  countryName: _trip!.countryName,
                  coverImageUri: _trip!.coverImageUri,
                  startDate: startDate,
                  endDate: endDate,
                ),
              ),
              const SizedBox(height: 24),
              WishlistHorizontalPadding(
                child: _TripDetailSection(
                  title: 'Destination',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        _trip!.countryName,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: <Widget>[
                          _TripDetailChip(
                            label: _formatDateRange(startDate, endDate),
                            icon: Icons.event_outlined,
                            emphasized: true,
                          ),
                          _TripDetailChip(
                            label:
                                '${_tripCities.length} ${_tripCities.length == 1 ? 'city' : 'cities'}',
                            icon: Icons.route_outlined,
                          ),
                          if (_trip!.sourceWishlistItemId != null)
                            const _TripDetailChip(
                              label: 'Started from wishlist',
                              icon: Icons.auto_awesome_outlined,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              WishlistHorizontalPadding(
                child: _TripDetailSection(
                  title: 'Route details',
                  child: _tripCities.isEmpty
                      ? Text(
                          'No city details are saved yet.',
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                        )
                      : Column(
                          children: <Widget>[
                            for (var index = 0;
                                index < _tripCities.length;
                                index += 1) ...<Widget>[
                              TripCityRouteCard(
                                city: _tripCities[index],
                                inheritedPlan:
                                    inheritance?.cityPlanFor(_tripCities[index].name),
                                inheritedDetail: inheritance
                                    ?.cityDetailFor(_tripCities[index].name),
                                showRemoveAction: false,
                                onOpen: () => _openCityGuide(
                                  _tripCities[index],
                                  inheritance: inheritance,
                                ),
                              ),
                              if (index != _tripCities.length - 1)
                                const SizedBox(height: 14),
                            ],
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 16),
              WishlistHorizontalPadding(
                child: _TripDetailSection(
                  title: 'Media & notes',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _pickTripCoverImage,
                              icon: const Icon(Icons.upload_file_rounded),
                              label: const Text('Upload image'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          TextButton(
                            onPressed: (_trip!.coverImageUri?.trim().isEmpty ?? true)
                                ? null
                                : _clearTripCoverImage,
                            child: const Text('Clear'),
                          ),
                        ],
                      ),
                      if ((_trip!.notes?.trim().isNotEmpty ?? false)) ...<Widget>[
                        const SizedBox(height: 16),
                        Text(
                          _trip!.notes!.trim(),
                          style:
                              Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _hydrateFromTrip(TripRecord trip) {
    final fingerprint = [
      trip.id,
      trip.countryCode,
      trip.countryName,
      trip.startDate,
      trip.endDate,
      trip.cities,
      trip.sourceWishlistItemId,
      trip.cityDataJson,
      trip.coverImageUri,
      trip.notes,
    ].join('|');
    if (_tripFingerprint == fingerprint) {
      return;
    }

    _tripFingerprint = fingerprint;
    _trip = trip;
    _tripCities = decodeTripCityEntries(
      cityDataJson: trip.cityDataJson,
      legacyCities: trip.cities,
    );
  }

  Future<void> _pickTripCoverImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
      withData: false,
    );
    if (!mounted || result == null || result.files.isEmpty || _trip == null) {
      return;
    }

    final path = result.files.single.path?.trim();
    if (path == null || path.isEmpty) {
      return;
    }

    await _persistTrip(
      _trip!.copyWith(coverImageUri: path),
    );
  }

  Future<void> _clearTripCoverImage() async {
    if (_trip == null) {
      return;
    }
    await _persistTrip(_trip!.copyWith(coverImageUri: ''));
  }

  Future<void> _openEditor() async {
    await context.push('/trips/edit/${widget.tripId}');
    ref.invalidate(tripByIdProvider(widget.tripId));
    if (_trip?.sourceWishlistItemId != null) {
      ref.invalidate(wishlistItemProvider(_trip!.sourceWishlistItemId!));
    }
  }

  Future<void> _openCityGuide(
    TripCityEntry city, {
    required TripWishlistInheritance? inheritance,
  }) async {
    if (_trip == null) {
      return;
    }

    final updatedCity = await Navigator.of(context).push<TripCityEntry>(
      MaterialPageRoute<TripCityEntry>(
        builder: (_) => TripCityDetailScreen(
          city: city,
          countryName: _trip!.countryName,
          inheritedPlan: inheritance?.cityPlanFor(city.name),
          inheritedDetail: inheritance?.cityDetailFor(city.name),
        ),
      ),
    );

    if (!mounted || updatedCity == null || _trip == null) {
      return;
    }

    final updatedCities = _tripCities
        .map(
          (entry) => normalizeTripCityName(entry.name) ==
                  normalizeTripCityName(city.name)
              ? updatedCity
              : entry,
        )
        .toList(growable: false);

    await _persistTrip(
      _trip!.copyWith(
        cities: joinTripCityNames(updatedCities),
        cityDataJson: encodeTripCityEntries(updatedCities),
      ),
    );
  }

  Future<void> _persistTrip(TripRecord nextTrip) async {
    await ref.read(tripsRepositoryProvider).updateTrip(nextTrip);
    if (!mounted) {
      return;
    }
    ref.invalidate(tripByIdProvider(widget.tripId));
    setState(() {
      _trip = nextTrip;
      _tripCities = decodeTripCityEntries(
        cityDataJson: nextTrip.cityDataJson,
        legacyCities: nextTrip.cities,
      );
      _tripFingerprint = null;
    });
  }

  String _formatDateRange(DateTime startDate, DateTime endDate) {
    final formatter = DateFormat('MMM d');
    final yearFormatter = DateFormat('MMM d, y');
    final startLabel = startDate.year == endDate.year
        ? formatter.format(startDate)
        : yearFormatter.format(startDate);
    return '$startLabel - ${yearFormatter.format(endDate)}';
  }
}

class _TripDetailShell extends StatelessWidget {
  const _TripDetailShell({
    required this.title,
    required this.body,
    this.onEdit,
  });

  final String title;
  final Widget body;
  final VoidCallback? onEdit;

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
              child: IgnorePointer(
                child: WishlistAtmosphere(),
              ),
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
                  child: _TripDetailTopBar(
                    title: title,
                    onBack: () => Navigator.of(context).maybePop(),
                    onEdit: onEdit,
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

class _TripDetailTopBar extends StatelessWidget {
  const _TripDetailTopBar({
    required this.title,
    required this.onBack,
    this.onEdit,
  });

  final String title;
  final VoidCallback onBack;
  final VoidCallback? onEdit;

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
        height: 42,
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
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontSize: 24,
                      height: 1,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
            SizedBox(
              width: 84,
              child: Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  onPressed: onEdit,
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 30, minHeight: 30),
                  visualDensity: VisualDensity.compact,
                  icon: Icon(
                    Icons.edit_outlined,
                    size: 20,
                    color: onEdit == null
                        ? scheme.onSurface.withValues(alpha: 0.34)
                        : scheme.onSurface,
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

class _TripDetailSection extends StatelessWidget {
  const _TripDetailSection({
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
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _TripDetailChip extends StatelessWidget {
  const _TripDetailChip({
    required this.label,
    this.icon,
    this.emphasized = false,
  });

  final String label;
  final IconData? icon;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: ShapeDecoration(
        color: emphasized
            ? scheme.primaryContainer.withValues(alpha: 0.36)
            : scheme.surface.withValues(alpha: 0.72),
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
            if (icon != null) ...<Widget>[
              Icon(icon, size: 14, color: scheme.onSurfaceVariant),
              const SizedBox(width: 6),
            ],
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
