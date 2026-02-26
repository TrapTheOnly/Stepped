import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/db/app_db.dart';
import '../../data/repositories/trips_repository.dart';
import '../../data/repositories/visits_repository.dart';
import '../map/map_viewmodel.dart';
import '../map/globe/globe_country_data.dart';
import '../../widgets/country_flag.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final TextEditingController _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final datasetAsync = ref.watch(globeCountryDatasetProvider);
    final tripsAsync = ref.watch(tripsStreamProvider);
    final visitsAsync = ref.watch(visitedCountriesProvider);

    final dataset = datasetAsync.valueOrNull;
    final trips = tripsAsync.valueOrNull ?? const <TripRecord>[];
    final visits = visitsAsync.valueOrNull ?? const <CountryVisitRecord>[];
    final loading =
        datasetAsync.isLoading || tripsAsync.isLoading || visitsAsync.isLoading;

    final error = datasetAsync.error ?? tripsAsync.error ?? visitsAsync.error;
    final results = dataset == null
        ? const <_CountrySearchEntry>[]
        : _buildResults(
            query: _query,
            datasetCountries: dataset.countries,
            trips: trips,
            visits: visits,
          );

    return Scaffold(
      appBar: AppBar(title: const Text('Search')),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: SearchBar(
                controller: _controller,
                hintText: 'Search countries',
                leading: const Icon(Icons.search),
                trailing: _query.isEmpty
                    ? null
                    : <Widget>[
                        IconButton(
                          tooltip: 'Clear search',
                          onPressed: () {
                            _controller.clear();
                            setState(() {
                              _query = '';
                            });
                          },
                          icon: const Icon(Icons.close),
                        ),
                      ],
                onChanged: (value) {
                  setState(() {
                    _query = value;
                  });
                },
              ),
            ),
            if (loading) const LinearProgressIndicator(minHeight: 2),
            if (error != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Text(
                  'Search data failed to load: $error',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            Expanded(
              child: dataset == null
                  ? const Center(child: CircularProgressIndicator())
                  : results.isEmpty
                      ? const Center(child: Text('No countries found.'))
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(8, 8, 8, 16),
                          itemCount: results.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final entry = results[index];
                            return Semantics(
                              label: 'Country ${entry.name}',
                              child: ListTile(
                                leading: CountryFlag(
                                  iso2: entry.iso2,
                                  width: 28,
                                  height: 20,
                                ),
                                title: Text(entry.name),
                                subtitle: Text(
                                  '${entry.iso2} · ${entry.continent ?? 'Unknown continent'}',
                                ),
                                trailing: Wrap(
                                  spacing: 8,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: <Widget>[
                                    if (entry.visited)
                                      Icon(
                                        Icons.check_circle,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary,
                                      ),
                                    if (entry.tripCount > 0)
                                      Chip(
                                        visualDensity: VisualDensity.compact,
                                        label: Text(
                                          '${entry.tripCount} trip${entry.tripCount == 1 ? '' : 's'}',
                                        ),
                                      ),
                                  ],
                                ),
                                onTap: () => _showCountryActions(
                                  context: context,
                                  ref: ref,
                                  entry: entry,
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  List<_CountrySearchEntry> _buildResults({
    required String query,
    required List<GlobeCountryShape> datasetCountries,
    required List<TripRecord> trips,
    required List<CountryVisitRecord> visits,
  }) {
    final visitedSet = <String>{
      for (final visit in visits) visit.countryCode.toUpperCase(),
    };

    final tripsByCode = <String, List<TripRecord>>{};
    for (final trip in trips) {
      final code = trip.countryCode.toUpperCase();
      tripsByCode.putIfAbsent(code, () => <TripRecord>[]).add(trip);
    }

    final refs = <_SearchCountryRef>[
      for (final country in datasetCountries)
        _SearchCountryRef(
          iso2: country.iso2,
          name: country.name,
          continent: country.continent,
          focusableOnGlobe: true,
        ),
      ..._microstateSearchOnly,
    ];

    final q = query.trim().toLowerCase();
    final filtered = <_CountrySearchEntry>[];

    for (final refItem in refs) {
      final iso2Lower = refItem.iso2.toLowerCase();
      final nameLower = refItem.name.toLowerCase();
      if (q.isNotEmpty && !nameLower.contains(q) && !iso2Lower.contains(q)) {
        continue;
      }

      final tripsForCountry =
          tripsByCode[refItem.iso2.toUpperCase()] ?? const <TripRecord>[];
      final latestTripId = tripsForCountry
          .where((trip) => trip.id != null)
          .map((trip) => trip.id!)
          .firstOrNull;

      filtered.add(
        _CountrySearchEntry(
          iso2: refItem.iso2,
          name: refItem.name,
          continent: refItem.continent,
          focusableOnGlobe: refItem.focusableOnGlobe,
          visited: visitedSet.contains(refItem.iso2.toUpperCase()),
          tripCount: tripsForCountry.length,
          latestTripId: latestTripId,
        ),
      );
    }

    filtered.sort((left, right) {
      final leftRank = _searchRank(left, q);
      final rightRank = _searchRank(right, q);
      if (leftRank != rightRank) {
        return leftRank.compareTo(rightRank);
      }
      if (left.visited != right.visited) {
        return left.visited ? -1 : 1;
      }
      if (left.tripCount != right.tripCount) {
        return right.tripCount.compareTo(left.tripCount);
      }
      return left.name.compareTo(right.name);
    });

    final maxResults = q.isEmpty ? 120 : 200;
    if (filtered.length <= maxResults) {
      return filtered;
    }
    return filtered.take(maxResults).toList(growable: false);
  }

  int _searchRank(_CountrySearchEntry entry, String query) {
    if (query.isEmpty) {
      return 5;
    }

    final name = entry.name.toLowerCase();
    final iso2 = entry.iso2.toLowerCase();

    if (name == query || iso2 == query) {
      return 0;
    }
    if (name.startsWith(query) || iso2.startsWith(query)) {
      return 1;
    }
    return 2;
  }

  Future<void> _showCountryActions({
    required BuildContext context,
    required WidgetRef ref,
    required _CountrySearchEntry entry,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ListTile(
                leading: CountryFlag(
                  iso2: entry.iso2,
                  width: 28,
                  height: 20,
                ),
                title: Text(entry.name),
                subtitle: Text(
                  '${entry.iso2} · ${entry.continent ?? 'Unknown continent'}',
                ),
              ),
              ListTile(
                leading: const Icon(Icons.public),
                title: const Text('Show on globe'),
                enabled: entry.focusableOnGlobe,
                onTap: !entry.focusableOnGlobe
                    ? null
                    : () {
                        FocusManager.instance.primaryFocus?.unfocus();
                        Navigator.of(sheetContext).pop();
                        ref.read(globeFocusRequestProvider.notifier).state =
                            GlobeFocusRequest(
                          countryCode: entry.iso2,
                          token: DateTime.now().microsecondsSinceEpoch,
                        );
                        context.go('/');
                      },
              ),
              if (entry.latestTripId != null)
                ListTile(
                  leading: const Icon(Icons.flight_takeoff),
                  title: const Text('Open latest trip'),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    context.push('/trips/edit/${entry.latestTripId}');
                  },
                ),
              ListTile(
                leading: const Icon(Icons.add),
                title: const Text('Add trip'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  context.push('/trips/add');
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CountrySearchEntry {
  const _CountrySearchEntry({
    required this.iso2,
    required this.name,
    required this.continent,
    required this.focusableOnGlobe,
    required this.visited,
    required this.tripCount,
    required this.latestTripId,
  });

  final String iso2;
  final String name;
  final String? continent;
  final bool focusableOnGlobe;
  final bool visited;
  final int tripCount;
  final int? latestTripId;
}

class _SearchCountryRef {
  const _SearchCountryRef({
    required this.iso2,
    required this.name,
    required this.continent,
    required this.focusableOnGlobe,
  });

  final String iso2;
  final String name;
  final String? continent;
  final bool focusableOnGlobe;
}

const _microstateSearchOnly = <_SearchCountryRef>[
  _SearchCountryRef(
    iso2: 'AD',
    name: 'Andorra',
    continent: 'Europe',
    focusableOnGlobe: false,
  ),
  _SearchCountryRef(
    iso2: 'LI',
    name: 'Liechtenstein',
    continent: 'Europe',
    focusableOnGlobe: false,
  ),
  _SearchCountryRef(
    iso2: 'MC',
    name: 'Monaco',
    continent: 'Europe',
    focusableOnGlobe: false,
  ),
  _SearchCountryRef(
    iso2: 'SM',
    name: 'San Marino',
    continent: 'Europe',
    focusableOnGlobe: false,
  ),
  _SearchCountryRef(
    iso2: 'VA',
    name: 'Vatican City',
    continent: 'Europe',
    focusableOnGlobe: false,
  ),
];

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
