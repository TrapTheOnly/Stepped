import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/db/app_db.dart';
import '../../data/repositories/wishlist_repository.dart';
import '../../widgets/country_flag.dart';
import '../map/map_viewmodel.dart';
import '../map/globe/globe_country_data.dart';
import '../settings/app_preferences.dart';
import 'gemini_trip_planner.dart';

class WishlistPlanScreen extends ConsumerStatefulWidget {
  const WishlistPlanScreen({
    super.key,
    required this.itemId,
  });

  final int itemId;

  @override
  ConsumerState<WishlistPlanScreen> createState() => _WishlistPlanScreenState();
}

class _WishlistPlanScreenState extends ConsumerState<WishlistPlanScreen> {
  final TextEditingController _countryController = TextEditingController();
  final TextEditingController _citiesController = TextEditingController();
  final FocusNode _countryFocusNode = FocusNode();

  bool _didHydrate = false;
  bool _noDates = true;
  bool _noCities = true;
  bool _isGenerating = false;

  DateTimeRange? _dateRange;
  String? _selectedCountryCode;
  GeminiTripPlan? _plan;
  String? _errorText;
  Map<String, _CountryOption> _countriesByCode = const <String, _CountryOption>{};

  @override
  void dispose() {
    _countryController.dispose();
    _citiesController.dispose();
    _countryFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final itemAsync = ref.watch(wishlistItemProvider(widget.itemId));
    final datasetAsync = ref.watch(globeCountryDatasetProvider);
    final prefs = ref.watch(appPreferencesProvider).valueOrNull ??
        AppPreferences.defaults;

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Trip Planner'),
      ),
      body: itemAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Failed to load item: $error')),
        data: (item) {
          if (item == null) {
            return const Center(child: Text('Wishlist item not found.'));
          }

          final options = _buildCountryOptions(datasetAsync.valueOrNull);
          _countriesByCode = {
            for (final option in options) option.code.toUpperCase(): option,
          };

          if (!_didHydrate) {
            _hydrateFromItem(item);
          }

          final selectedCountryName = _resolveCountryName();
          final canGenerate = !_isGenerating &&
              prefs.geminiApiKey.trim().isNotEmpty &&
              selectedCountryName.isNotEmpty;

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            children: <Widget>[
              _HeaderCard(itemTitle: item.title),
              const SizedBox(height: 12),
              if (prefs.geminiApiKey.trim().isEmpty) ...<Widget>[
                Card(
                  color: Theme.of(context).colorScheme.errorContainer,
                  child: ListTile(
                    leading: Icon(
                      Icons.key_off_outlined,
                      color: Theme.of(context).colorScheme.onErrorContainer,
                    ),
                    title: Text(
                      'Gemini API key is missing',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onErrorContainer,
                      ),
                    ),
                    subtitle: Text(
                      'Open Settings and add your Gemini key to use AI planning.',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onErrorContainer,
                      ),
                    ),
                    trailing: FilledButton(
                      onPressed: () => context.push('/profile/settings'),
                      child: const Text('Settings'),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              Card(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        '1) Destination country',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 10),
                      if (datasetAsync.isLoading)
                        const LinearProgressIndicator(minHeight: 2),
                      if (datasetAsync.hasError)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            'Country list unavailable: ${datasetAsync.error}',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ),
                      RawAutocomplete<_CountryOption>(
                        textEditingController: _countryController,
                        focusNode: _countryFocusNode,
                        displayStringForOption: (option) => option.name,
                        optionsBuilder: (textValue) {
                          final query = textValue.text.trim().toLowerCase();
                          if (query.isEmpty) {
                            return options.take(12);
                          }
                          return options.where((option) {
                            return option.name.toLowerCase().contains(query) ||
                                option.code.toLowerCase().contains(query);
                          }).take(12);
                        },
                        onSelected: (option) {
                          setState(() {
                            _selectedCountryCode = option.code;
                            _errorText = null;
                          });
                        },
                        fieldViewBuilder:
                            (context, controller, focusNode, onFieldSubmitted) {
                          return TextField(
                            controller: controller,
                            focusNode: focusNode,
                            decoration: const InputDecoration(
                              labelText: 'Country',
                              hintText: 'Start typing a country',
                              prefixIcon: Icon(Icons.public_outlined),
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (value) {
                              _syncCountrySelection(value);
                            },
                          );
                        },
                        optionsViewBuilder: (context, onSelected, matches) {
                          return Align(
                            alignment: Alignment.topLeft,
                            child: Material(
                              elevation: 8,
                              borderRadius: BorderRadius.circular(14),
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 480,
                                  maxHeight: 280,
                                ),
                                child: ListView.builder(
                                  padding: const EdgeInsets.symmetric(vertical: 6),
                                  shrinkWrap: true,
                                  itemCount: matches.length,
                                  itemBuilder: (context, index) {
                                    final option = matches.elementAt(index);
                                    return ListTile(
                                      dense: true,
                                      leading: CountryFlag(
                                        iso2: option.code,
                                        width: 26,
                                        height: 18,
                                      ),
                                      title: Text(option.name),
                                      subtitle: Text(option.code),
                                      onTap: () => onSelected(option),
                                    );
                                  },
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      if (selectedCountryName.isNotEmpty) ...<Widget>[
                        const SizedBox(height: 8),
                        Row(
                          children: <Widget>[
                            if (_selectedCountryCode != null)
                              CountryFlag(
                                iso2: _selectedCountryCode!,
                                width: 28,
                                height: 20,
                              ),
                            if (_selectedCountryCode != null)
                              const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                selectedCountryName,
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        '2) Preferred travel window',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 10),
                      SwitchListTile(
                        value: _noDates,
                        title: const Text("I don't have exact dates"),
                        contentPadding: EdgeInsets.zero,
                        onChanged: (value) {
                          setState(() {
                            _noDates = value;
                            if (value) {
                              _dateRange = null;
                            }
                          });
                        },
                      ),
                      if (!_noDates)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.date_range_outlined),
                          title: Text(
                            _dateRange == null
                                ? 'Pick a date range'
                                : '${_formatDate(_dateRange!.start)} - ${_formatDate(_dateRange!.end)}',
                          ),
                          trailing: TextButton(
                            onPressed: _pickDateRange,
                            child: Text(_dateRange == null ? 'Select' : 'Change'),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        '3) Cities in your mind',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 10),
                      SwitchListTile(
                        value: _noCities,
                        title: const Text("I don't have cities yet"),
                        contentPadding: EdgeInsets.zero,
                        onChanged: (value) {
                          setState(() {
                            _noCities = value;
                            if (value) {
                              _citiesController.clear();
                            }
                          });
                        },
                      ),
                      if (!_noCities)
                        TextField(
                          controller: _citiesController,
                          decoration: const InputDecoration(
                            labelText: 'Preferred cities',
                            hintText: 'Tokyo, Kyoto, Osaka',
                            border: OutlineInputBorder(),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: canGenerate ? () => _generatePlan(item, prefs) : null,
                icon: _isGenerating
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.auto_awesome_outlined),
                label: Text(_isGenerating ? 'Generating...' : 'Generate AI Plan'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
              if (_errorText != null) ...<Widget>[
                const SizedBox(height: 10),
                Text(
                  _errorText!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              if (_plan != null) ...<Widget>[
                const SizedBox(height: 12),
                _PlanResultCard(plan: _plan!),
              ],
            ],
          );
        },
      ),
    );
  }

  void _hydrateFromItem(WishlistItemRecord item) {
    _countryController.text = item.countryName ?? '';
    _selectedCountryCode = item.countryCode;
    if ((item.plannedCities ?? '').trim().isNotEmpty) {
      _citiesController.text = item.plannedCities!.trim();
      _noCities = false;
    } else {
      _noCities = true;
    }
    if (item.plannedStartDate != null && item.plannedEndDate != null) {
      _dateRange = DateTimeRange(
        start: DateTime.fromMillisecondsSinceEpoch(item.plannedStartDate!),
        end: DateTime.fromMillisecondsSinceEpoch(item.plannedEndDate!),
      );
      _noDates = false;
    } else {
      _noDates = true;
    }

    final existingPlan = _tryParseStoredPlan(item.aiPlan);
    if (existingPlan != null) {
      _plan = existingPlan;
    }

    _didHydrate = true;
  }

  GeminiTripPlan? _tryParseStoredPlan(String? rawPlan) {
    final raw = rawPlan?.trim();
    if (raw == null || raw.isEmpty) {
      return null;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }
      final country = (decoded['country'] as String?)?.trim();
      final summary = (decoded['summary'] as String?)?.trim();
      final windowsRaw = decoded['time_windows'];
      final cityRaw = decoded['city_plan'];

      final windows = <GeminiTimeWindow>[];
      if (windowsRaw is List) {
        for (final item in windowsRaw) {
          if (item is! Map<String, dynamic>) {
            continue;
          }
          final label = (item['label'] as String?)?.trim();
          final months = (item['months'] as String?)?.trim();
          final reason = (item['reason'] as String?)?.trim();
          if (label == null || months == null || reason == null) {
            continue;
          }
          windows.add(
            GeminiTimeWindow(label: label, months: months, reason: reason),
          );
        }
      }

      final cities = <GeminiCityPlan>[];
      if (cityRaw is List) {
        for (final item in cityRaw) {
          if (item is! Map<String, dynamic>) {
            continue;
          }
          final city = (item['city'] as String?)?.trim();
          final days = item['days'];
          final reason = (item['reason'] as String?)?.trim();
          final daysValue = days is int
              ? days
              : days is num
                  ? days.round()
                  : days is String
                      ? int.tryParse(days.trim())
                      : null;
          if (city == null || reason == null || daysValue == null) {
            continue;
          }
          cities.add(
            GeminiCityPlan(
              city: city,
              days: daysValue.clamp(1, 30),
              reason: reason,
            ),
          );
        }
      }

      return GeminiTripPlan(
        country: country ?? _resolveCountryName(),
        summary: summary ?? '',
        timeWindows: windows,
        cityPlan: cities,
        rawText: raw,
      );
    } catch (_) {
      return null;
    }
  }

  List<_CountryOption> _buildCountryOptions(GlobeCountryDataset? dataset) {
    if (dataset == null) {
      return const <_CountryOption>[];
    }
    final options = dataset.countries
        .map(
          (country) => _CountryOption(
            code: country.iso2.toUpperCase(),
            name: country.name,
          ),
        )
        .toList(growable: false)
      ..sort((left, right) => left.name.compareTo(right.name));
    return options;
  }

  void _syncCountrySelection(String rawValue) {
    final query = rawValue.trim().toLowerCase();
    if (query.isEmpty) {
      setState(() {
        _selectedCountryCode = null;
      });
      return;
    }

    _CountryOption? exact;
    for (final option in _countriesByCode.values) {
      if (option.name.toLowerCase() == query || option.code.toLowerCase() == query) {
        exact = option;
        break;
      }
    }

    setState(() {
      _selectedCountryCode = exact?.code;
    });
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final initialRange = _dateRange ??
        DateTimeRange(
          start: now,
          end: now.add(const Duration(days: 6)),
        );
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
      initialDateRange: initialRange,
    );
    if (picked == null) {
      return;
    }
    setState(() {
      _dateRange = picked;
    });
  }

  Future<void> _generatePlan(
    WishlistItemRecord item,
    AppPreferences prefs,
  ) async {
    final countryName = _resolveCountryName();
    if (countryName.isEmpty) {
      setState(() {
        _errorText = 'Please choose a country first.';
      });
      return;
    }

    final preferredCities = _noCities
        ? const <String>[]
        : _citiesController.text
            .split(',')
            .map((part) => part.trim())
            .where((part) => part.isNotEmpty)
            .toList(growable: false);

    setState(() {
      _isGenerating = true;
      _errorText = null;
    });

    try {
      final planner = ref.read(geminiTripPlannerProvider);
      final plan = await planner.generatePlan(
        apiKey: prefs.geminiApiKey,
        countryName: countryName,
        homeBase: prefs.homeBase,
        plannedWindow: _noDates ? null : _dateRange,
        preferredCities: preferredCities,
      );

      setState(() {
        _plan = plan;
      });

      await _saveDraft(item, plan: plan);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('AI plan generated and saved.')),
      );
    } catch (error) {
      setState(() {
        _errorText = '$error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isGenerating = false;
        });
      }
    }
  }

  Future<void> _saveDraft(
    WishlistItemRecord item, {
    GeminiTripPlan? plan,
  }) async {
    final id = item.id;
    if (id == null) {
      return;
    }

    final countryName = _resolveCountryName();
    final plannedCities = _noCities ? null : _citiesController.text.trim();
    final payload = plan == null
        ? item.aiPlan
        : jsonEncode(
            <String, dynamic>{
              'country': plan.country,
              'summary': plan.summary,
              'time_windows': [
                for (final window in plan.timeWindows)
                  <String, dynamic>{
                    'label': window.label,
                    'months': window.months,
                    'reason': window.reason,
                  },
              ],
              'city_plan': [
                for (final city in plan.cityPlan)
                  <String, dynamic>{
                    'city': city.city,
                    'days': city.days,
                    'reason': city.reason,
                  },
              ],
            },
          );

    await ref.read(wishlistRepositoryProvider).updateWishlistItem(
          item.copyWith(
            countryName: countryName.isEmpty ? null : countryName,
            countryCode: _selectedCountryCode,
            plannedStartDate:
                _noDates ? null : _dateRange?.start.millisecondsSinceEpoch,
            plannedEndDate: _noDates ? null : _dateRange?.end.millisecondsSinceEpoch,
            plannedCities:
                plannedCities == null || plannedCities.isEmpty ? null : plannedCities,
            aiPlan: payload,
          ),
        );
  }

  String _resolveCountryName() {
    final typed = _countryController.text.trim();
    if (typed.isEmpty) {
      return '';
    }
    if (_selectedCountryCode == null) {
      return typed;
    }
    final resolved = _countriesByCode[_selectedCountryCode!.toUpperCase()];
    return resolved?.name ?? typed;
  }

  String _formatDate(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.itemTitle});

  final String itemTitle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Row(
          children: <Widget>[
            CircleAvatar(
              radius: 23,
              backgroundColor: scheme.secondaryContainer,
              child: Icon(
                Icons.route_outlined,
                color: scheme.onSecondaryContainer,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    itemTitle,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Generate a city-level plan and optimal visiting windows.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
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

class _PlanResultCard extends StatelessWidget {
  const _PlanResultCard({required this.plan});

  final GeminiTripPlan plan;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'AI Recommendation',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(plan.summary),
            if (plan.timeWindows.isNotEmpty) ...<Widget>[
              const SizedBox(height: 12),
              Text(
                'Best Time Windows',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 6),
              ...plan.timeWindows.map(
                (window) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          window.label,
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                        const SizedBox(height: 2),
                        Text(window.months),
                        const SizedBox(height: 4),
                        Text(
                          window.reason,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
            if (plan.cityPlan.isNotEmpty) ...<Widget>[
              const SizedBox(height: 4),
              Text(
                'City Plan',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 6),
              ...plan.cityPlan.map(
                (city) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  leading: CircleAvatar(
                    radius: 14,
                    child: Text('${city.days}d'),
                  ),
                  title: Text(city.city),
                  subtitle: Text(city.reason),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CountryOption {
  const _CountryOption({
    required this.code,
    required this.name,
  });

  final String code;
  final String name;
}
