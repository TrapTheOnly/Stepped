import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../data/db/app_db.dart';
import '../../data/repositories/trips_repository.dart';
import '../../data/repositories/visits_repository.dart';
import '../../domain/models/trip_ui.dart';
import '../../widgets/country_flag.dart';
import '../search/search_logic.dart';
import '../search/search_models.dart';
import '../../widgets/frosted_squircle.dart';
import '../../widgets/stepped_top_bar.dart';
import 'globe/globe_country_data.dart';
import 'globe/globe_widget.dart';
import 'map_viewmodel.dart';
import 'widgets/map_search_dock.dart';
import 'widgets/map_search_results_list.dart';

const _bottomDockHeight = 187.0;
const _bottomDockOffset = 110.0;
const _floatingControlGap = 10.0;

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  bool _isLocatingCurrentCountry = false;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  String _searchQuery = '';
  String? _selectedCountryCode;

  @override
  void initState() {
    super.initState();
    _searchFocusNode.addListener(_handleSearchFocusChange);
  }

  @override
  void dispose() {
    _searchFocusNode.removeListener(_handleSearchFocusChange);
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _handleSearchFocusChange() {
    if (mounted) {
      setState(() {});
    }
  }

  void _handleSearchChanged(String value) {
    final cleared = value.trim().isEmpty;
    setState(() {
      _searchQuery = value;
      if (cleared) {
        _selectedCountryCode = null;
      }
    });
    if (cleared) {
      _resetGlobeSelection();
    }
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _searchQuery = '';
      _selectedCountryCode = null;
    });
    _resetGlobeSelection();
    _searchFocusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<void>>(mapVisitToggleControllerProvider,
        (previous, next) {
      if (next.hasError) {
        final messenger = ScaffoldMessenger.maybeOf(context);
        if (messenger == null) {
          return;
        }
        messenger.showSnackBar(
          SnackBar(
            content: Text('Failed to update visited country: ${next.error}'),
          ),
        );
      }
    });

    final dashboardAsync = ref.watch(mapDashboardProvider);
    final datasetAsync = ref.watch(globeCountryDatasetProvider);
    final tripsAsync = ref.watch(tripsStreamProvider);
    final visitsAsync = ref.watch(visitedCountriesProvider);
    final focusRequest = ref.watch(globeFocusRequestProvider);
    final resetToken = ref.watch(globeResetRequestProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final dataset = datasetAsync.valueOrNull;
    final trips = tripsAsync.valueOrNull ?? const <TripRecord>[];
    final visits = visitsAsync.valueOrNull ?? const <CountryVisitRecord>[];
    final countryCatalog = dataset == null
        ? const <CountrySearchEntry>[]
        : buildCountrySearchCatalog(
            datasetCountries: dataset.countries,
            trips: trips,
            visits: visits,
          );
    final searchCatalogByIso2 = <String, CountrySearchEntry>{
      for (final entry in countryCatalog) entry.iso2.toUpperCase(): entry,
    };
    final selectedCountryEntry = _selectedCountryCode == null
        ? null
        : searchCatalogByIso2[_selectedCountryCode!.toUpperCase()];
    final searchResults = dataset == null
        ? const <CountrySearchEntry>[]
        : buildCountrySearchResults(
            query: _searchQuery,
            datasetCountries: dataset.countries,
            trips: trips,
            visits: visits,
          );
    final visibleSearchResults =
        _searchFocusNode.hasFocus && _searchQuery.trim().isNotEmpty
            ? searchResults.take(3).toList(growable: false)
            : const <CountrySearchEntry>[];

    return ColoredBox(
      color: colorScheme.surface,
      child: Stack(
        children: <Widget>[
          Positioned.fill(
            child: Transform.translate(
              offset: const Offset(0, -52),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, 8, 0, 30),
                child: GlobeWidget(
                  visitedCountryCodes:
                      dashboardAsync.valueOrNull?.visitedCountryCodes ??
                          const <String>[],
                  focusCountryCode: focusRequest?.countryCode,
                  focusRequestToken: focusRequest?.token,
                  resetViewRequestToken: resetToken,
                  onSelectedCountryChanged: _handleGlobeSelectedCountryChanged,
                  onFocusRequestConsumed: (countryCode, token) {
                    final activeRequest = ref.read(globeFocusRequestProvider);
                    if (activeRequest == null) {
                      return;
                    }

                    final matchesCountry =
                        activeRequest.countryCode.toUpperCase() ==
                            countryCode.toUpperCase();
                    final matchesToken =
                        token == null || activeRequest.token == token;
                    if (!matchesCountry || !matchesToken) {
                      return;
                    }

                    ref.read(globeFocusRequestProvider.notifier).state = null;
                  },
                ),
              ),
            ),
          ),
          const Positioned.fill(
            child: IgnorePointer(
              child: _MapAtmosphere(),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  SteppedTopBar(
                    onOpenSettings: () => context.push('/profile/settings'),
                    onOpenProfile: () => context.push('/profile'),
                  ),
                  const SizedBox(height: 14),
                  MapSearchDock(
                    controller: _searchController,
                    focusNode: _searchFocusNode,
                    onChanged: _handleSearchChanged,
                    onClear: _clearSearch,
                  ),
                  MapSearchResultsList(
                    results: visibleSearchResults,
                    onSelect: _handleSearchSelection,
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            right: 16,
            bottom: _bottomDockOffset + _bottomDockHeight + _floatingControlGap,
            child: _MapActionButton(
              icon: Icons.my_location_rounded,
              tooltip: _isLocatingCurrentCountry
                  ? 'Locating current country'
                  : 'Focus current country',
              isBusy: _isLocatingCurrentCountry,
              onTap: _focusCurrentCountry,
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: _bottomDockOffset,
            child: _DashboardDock(
              dashboardAsync: dashboardAsync,
              selectedCountry: selectedCountryEntry,
              onToggleVisited: selectedCountryEntry == null
                  ? null
                  : () => _toggleSelectedCountryVisited(selectedCountryEntry),
              onShowOnGlobe: selectedCountryEntry == null ||
                      !selectedCountryEntry.focusableOnGlobe
                  ? null
                  : () => _requestGlobeFocus(selectedCountryEntry.iso2),
              onOpenLatestTrip: selectedCountryEntry?.latestTripId == null
                  ? null
                  : () => context.push(
                        '/trips/view/${selectedCountryEntry!.latestTripId}',
                      ),
              onAddTrip: () => context.push(
                Uri(
                  path: '/trips/add',
                  queryParameters: <String, String>{
                    if (selectedCountryEntry != null)
                      'country': selectedCountryEntry.iso2,
                    if (selectedCountryEntry != null)
                      'countryName': selectedCountryEntry.name,
                  },
                ).toString(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _focusCurrentCountry() async {
    if (_isLocatingCurrentCountry) {
      return;
    }

    setState(() {
      _isLocatingCurrentCountry = true;
    });

    try {
      final locationEnabled = await Geolocator.isLocationServiceEnabled();
      if (!locationEnabled) {
        _showMapMessage(
            'Turn on location services to focus your current country.');
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _showMapMessage(
          'Location permission is needed to focus the globe on your current country.',
        );
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 12),
        ),
      );
      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      final dataset = await ref.read(globeCountryDatasetProvider.future);
      final countryCode = _resolveCurrentCountryCode(
        placemarks: placemarks,
        dataset: dataset,
      );
      if (countryCode == null) {
        _showMapMessage(
            'Could not determine your current country from location.');
        return;
      }

      setState(() {
        _selectedCountryCode = countryCode;
      });
      _requestGlobeFocus(countryCode);
    } on MissingPluginException {
      _showMapMessage(
        'Location services are not loaded in this app instance yet. Fully stop and relaunch the app once.',
      );
    } catch (error) {
      _showMapMessage('Unable to focus your current country: $error');
    } finally {
      if (mounted) {
        setState(() {
          _isLocatingCurrentCountry = false;
        });
      }
    }
  }

  void _handleSearchSelection(CountrySearchEntry entry) {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _selectedCountryCode = entry.iso2.toUpperCase();
    });
    if (!entry.focusableOnGlobe) {
      _showMapMessage('${entry.name} is not available on the globe yet.');
      return;
    }
    _requestGlobeFocus(entry.iso2);
  }

  void _handleGlobeSelectedCountryChanged(GlobeCountryShape? country) {
    final nextCountryCode = country?.iso2.toUpperCase();
    if (_selectedCountryCode == nextCountryCode) {
      return;
    }
    setState(() {
      _selectedCountryCode = nextCountryCode;
    });
  }

  void _requestGlobeFocus(String countryCode) {
    ref.read(globeFocusRequestProvider.notifier).state = GlobeFocusRequest(
      countryCode: countryCode,
      token: DateTime.now().microsecondsSinceEpoch,
    );
  }

  void _resetGlobeSelection() {
    ref.read(globeResetRequestProvider.notifier).state =
        DateTime.now().microsecondsSinceEpoch;
    ref.read(globeFocusRequestProvider.notifier).state = null;
  }

  Future<void> _toggleSelectedCountryVisited(CountrySearchEntry entry) {
    return ref.read(mapVisitToggleControllerProvider.notifier).setVisited(
          countryCode: entry.iso2,
          countryName: entry.name,
          visited: !entry.visited,
        );
  }

  String? _resolveCurrentCountryCode({
    required List<Placemark> placemarks,
    required GlobeCountryDataset dataset,
  }) {
    for (final placemark in placemarks) {
      final isoCode = placemark.isoCountryCode?.trim().toUpperCase();
      if (isoCode != null && dataset.byIso2.containsKey(isoCode)) {
        return isoCode;
      }
    }

    for (final placemark in placemarks) {
      final countryName = placemark.country?.trim().toLowerCase();
      if (countryName == null || countryName.isEmpty) {
        continue;
      }

      for (final country in dataset.countries) {
        if (country.name.trim().toLowerCase() == countryName) {
          return country.iso2;
        }
      }
    }

    return null;
  }

  void _showMapMessage(String message) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) {
      return;
    }
    messenger.showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}

class _MapAtmosphere extends StatelessWidget {
  const _MapAtmosphere();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            colorScheme.surface.withValues(alpha: 0.22),
            Colors.transparent,
            colorScheme.surface.withValues(alpha: 0.74),
          ],
          stops: const <double>[0, 0.42, 1],
        ),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(-0.32, 0.88),
            radius: 1.08,
            colors: <Color>[
              colorScheme.secondary.withValues(alpha: 0.24),
              colorScheme.primary.withValues(alpha: 0.14),
              Colors.transparent,
            ],
            stops: const <double>[0, 0.38, 1],
          ),
        ),
      ),
    );
  }
}

class _MapActionButton extends StatelessWidget {
  const _MapActionButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.isBusy = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool isBusy;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isBusy ? null : onTap,
          customBorder: squircleShape(24),
          child: FrostedSquircle(
            radius: 24,
            blurSigma: 18,
            color: colorScheme.surface.withValues(alpha: 0.62),
            borderColor: colorScheme.outlineVariant.withValues(alpha: 0.14),
            padding: const EdgeInsets.all(12),
            child: isBusy
                ? SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        colorScheme.onSurface,
                      ),
                    ),
                  )
                : Icon(
                    icon,
                    size: 18,
                    color: colorScheme.onSurface,
                  ),
          ),
        ),
      ),
    );
  }
}

class _DashboardDock extends StatelessWidget {
  const _DashboardDock({
    required this.dashboardAsync,
    required this.onAddTrip,
    this.selectedCountry,
    this.onToggleVisited,
    this.onShowOnGlobe,
    this.onOpenLatestTrip,
  });

  final AsyncValue<MapDashboardState> dashboardAsync;
  final CountrySearchEntry? selectedCountry;
  final VoidCallback? onToggleVisited;
  final VoidCallback? onShowOnGlobe;
  final VoidCallback? onOpenLatestTrip;
  final VoidCallback onAddTrip;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 260),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      child: selectedCountry == null
          ? dashboardAsync.when(
              loading: () => const _StatusDock(
                key: ValueKey<String>('loading'),
                title: 'Syncing field journal',
                subtitle: 'Loading your latest travel stats...',
              ),
              error: (error, _) => const _StatusDock(
                key: ValueKey<String>('error'),
                title: 'Field journal unavailable',
                subtitle: 'Unable to load your latest travel stats right now.',
              ),
              data: (dashboard) => _JourneyDock(
                key: const ValueKey<String>('journey'),
                dashboard: dashboard,
              ),
            )
          : _CountryDock(
              key: ValueKey<String>('country-${selectedCountry!.iso2}'),
              country: selectedCountry!,
              onToggleVisited: onToggleVisited,
              onShowOnGlobe: onShowOnGlobe,
              onOpenLatestTrip: onOpenLatestTrip,
              onAddTrip: onAddTrip,
            ),
    );
  }
}

class _CountryDock extends StatelessWidget {
  const _CountryDock({
    super.key,
    required this.country,
    required this.onAddTrip,
    this.onToggleVisited,
    this.onShowOnGlobe,
    this.onOpenLatestTrip,
  });

  final CountrySearchEntry country;
  final VoidCallback? onToggleVisited;
  final VoidCallback? onShowOnGlobe;
  final VoidCallback? onOpenLatestTrip;
  final VoidCallback onAddTrip;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final infoText = country.tripCount == 0
        ? 'No trips logged yet.'
        : '${country.tripCount} trip${country.tripCount == 1 ? '' : 's'} logged for ${country.name}.';

    return SizedBox(
      height: _bottomDockHeight,
      child: FrostedSquircle(
        radius: 38,
        blurSigma: 22,
        color: colorScheme.surface.withValues(alpha: 0.82),
        borderColor: colorScheme.primaryContainer.withValues(alpha: 0.18),
        shadowColor: colorScheme.secondary.withValues(alpha: 0.12),
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                CountryFlag(
                  iso2: country.iso2,
                  width: 36,
                  height: 26,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        country.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontSize: 23,
                            ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${country.iso2} · ${country.continent ?? 'Unknown continent'}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                _VisitedToggleChip(
                  visited: country.visited,
                  onTap: onToggleVisited,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                if (country.visited)
                  const _ResultMetaChip(
                    icon: Icons.check_circle_rounded,
                    label: 'Visited',
                  ),
                if (country.tripCount > 0)
                  _ResultMetaChip(
                    icon: Icons.flight_takeoff_rounded,
                    label:
                        '${country.tripCount} trip${country.tripCount == 1 ? '' : 's'}',
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              infoText,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    letterSpacing: 0.2,
                  ),
            ),
            const Spacer(),
            Row(
              children: <Widget>[
                _CountryIconButton(
                  icon: onShowOnGlobe == null
                      ? Icons.public_off_rounded
                      : Icons.public_rounded,
                  tooltip: onShowOnGlobe == null
                      ? 'Not available on the globe'
                      : 'Refocus on the globe',
                  onTap: onShowOnGlobe,
                ),
                const SizedBox(width: 10),
                if (onOpenLatestTrip != null)
                  Expanded(
                    child: _CountryActionButton(
                      icon: Icons.flight_takeoff_rounded,
                      label: 'Latest trip',
                      onTap: onOpenLatestTrip,
                    ),
                  ),
                if (onOpenLatestTrip != null) const SizedBox(width: 8),
                Expanded(
                  child: _CountryActionButton(
                    icon: Icons.add_rounded,
                    label: 'Add trip',
                    onTap: onAddTrip,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusDock extends StatelessWidget {
  const _StatusDock({
    super.key,
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SizedBox(
      height: _bottomDockHeight,
      child: FrostedSquircle(
        radius: 38,
        blurSigma: 22,
        color: colorScheme.surface.withValues(alpha: 0.78),
        borderColor: colorScheme.primaryContainer.withValues(alpha: 0.16),
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
            ),
            const Spacer(),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: const LinearProgressIndicator(minHeight: 6),
            ),
          ],
        ),
      ),
    );
  }
}

class _JourneyDock extends StatelessWidget {
  const _JourneyDock({
    super.key,
    required this.dashboard,
  });

  final MapDashboardState dashboard;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final progress = totalCountriesInWorld == 0
        ? 0.0
        : (dashboard.visitedCount / totalCountriesInWorld).clamp(0.0, 1.0);
    final latestTrip =
        dashboard.recentTrips.isEmpty ? null : dashboard.recentTrips.first;

    return SizedBox(
      height: _bottomDockHeight,
      child: FrostedSquircle(
        radius: 38,
        blurSigma: 22,
        color: colorScheme.surface.withValues(alpha: 0.8),
        borderColor: colorScheme.primaryContainer.withValues(alpha: 0.18),
        shadowColor: colorScheme.secondary.withValues(alpha: 0.12),
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: RichText(
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      text: TextSpan(
                        children: <InlineSpan>[
                          TextSpan(
                            text: 'You\'ve ',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w500,
                                ),
                          ),
                          TextSpan(
                            text: 'Stepped',
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(
                                  fontSize: 24,
                                  letterSpacing: 1.4,
                                  color: colorScheme.onSurface,
                                ),
                          ),
                          TextSpan(
                            text: ' on',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w500,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                _VisitedCounter(visitedCount: dashboard.visitedCount),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: SizedBox(
                height: 7,
                child: Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    ColoredBox(
                      color: colorScheme.surfaceContainerHighest.withValues(
                        alpha: 0.72,
                      ),
                    ),
                    FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: progress,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: <Color>[
                              colorScheme.primary,
                              colorScheme.primaryContainer,
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: <Widget>[
                Expanded(
                  child: _SummaryMetric(
                    label: 'Trips logged',
                    value: '${dashboard.totalTrips}',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _SummaryMetric(
                    label: 'Continent reach',
                    value:
                        '${dashboard.continentsVisited}/$totalContinentsInWorld',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _DockFooter(
              latestTrip: latestTrip,
              coveragePercent: (progress * 100).round(),
            ),
          ],
        ),
      ),
    );
  }
}

class _VisitedCounter extends StatelessWidget {
  const _VisitedCounter({required this.visitedCount});

  final int visitedCount;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return RichText(
      textAlign: TextAlign.right,
      text: TextSpan(
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
        children: <InlineSpan>[
          TextSpan(
            text: '$visitedCount',
            style: Theme.of(context).textTheme.displayMedium?.copyWith(
                  fontSize: 31,
                  color: colorScheme.onSurface,
                ),
          ),
          TextSpan(
            text: '/$totalCountriesInWorld',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontSize: 13,
                ),
          ),
        ],
      ),
    );
  }
}

class _VisitedToggleChip extends StatelessWidget {
  const _VisitedToggleChip({
    required this.visited,
    required this.onTap,
  });

  final bool visited;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        customBorder: squircleShape(18),
        child: DecoratedBox(
          decoration: ShapeDecoration(
            color: visited
                ? colorScheme.primary.withValues(alpha: 0.16)
                : colorScheme.surfaceContainerHighest.withValues(alpha: 0.72),
            shape: squircleShape(18),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(
                  visited ? Icons.check_circle_rounded : Icons.add_task_rounded,
                  size: 16,
                  color: visited
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Text(
                  visited ? 'Visited' : 'Mark visited',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: visited
                            ? colorScheme.primary
                            : colorScheme.onSurfaceVariant,
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

class _ResultMetaChip extends StatelessWidget {
  const _ResultMetaChip({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 14, color: colorScheme.primary),
            const SizedBox(width: 6),
            Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CountryIconButton extends StatelessWidget {
  const _CountryIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          customBorder: squircleShape(22),
          child: DecoratedBox(
            decoration: ShapeDecoration(
              color: onTap == null
                  ? colorScheme.surfaceContainerHighest.withValues(alpha: 0.35)
                  : colorScheme.surfaceContainerHighest.withValues(alpha: 0.58),
              shape: squircleShape(22),
            ),
            child: Padding(
              padding: const EdgeInsets.all(11),
              child: Icon(
                icon,
                size: 18,
                color: onTap == null
                    ? colorScheme.onSurfaceVariant.withValues(alpha: 0.55)
                    : colorScheme.primary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CountryActionButton extends StatelessWidget {
  const _CountryActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        customBorder: squircleShape(22),
        child: DecoratedBox(
          decoration: ShapeDecoration(
            color: onTap == null
                ? colorScheme.surfaceContainerHighest.withValues(alpha: 0.35)
                : colorScheme.surfaceContainerHighest.withValues(alpha: 0.58),
            shape: squircleShape(22),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Icon(
                  icon,
                  size: 16,
                  color: onTap == null
                      ? colorScheme.onSurfaceVariant.withValues(alpha: 0.55)
                      : colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: onTap == null
                              ? colorScheme.onSurfaceVariant
                                  .withValues(alpha: 0.6)
                              : colorScheme.onSurface,
                        ),
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

class _SummaryMetric extends StatelessWidget {
  const _SummaryMetric({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: ShapeDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.46),
        shape: squircleShape(24),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              value,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: colorScheme.onSurface,
                    fontSize: 17,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    letterSpacing: 0.75,
                    fontSize: 10,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DockFooter extends StatelessWidget {
  const _DockFooter({
    required this.latestTrip,
    required this.coveragePercent,
  });

  final TripUi? latestTrip;
  final int coveragePercent;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final latestText = latestTrip == null
        ? 'FIELD JOURNAL ACTIVE'
        : 'LATEST ENTRY · ${latestTrip!.countryName.toUpperCase()}';

    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            latestText,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  letterSpacing: 0.9,
                  fontSize: 10,
                ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          'COVERAGE $coveragePercent%',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: colorScheme.primaryContainer,
                letterSpacing: 0.9,
                fontSize: 10,
              ),
        ),
      ],
    );
  }
}
