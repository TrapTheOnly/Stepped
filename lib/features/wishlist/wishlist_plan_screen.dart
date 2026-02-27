import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/db/app_db.dart';
import '../../data/repositories/wishlist_repository.dart';
import '../../widgets/country_flag.dart';
import '../map/globe/globe_country_data.dart';
import '../map/map_viewmodel.dart';
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
  bool _noCities = true;
  bool _allowAdditionalCities = true;
  bool _isGenerating = false;

  _TimeInputMode _timeInputMode = _TimeInputMode.aiRecommended;
  DateTimeRange? _dateRange;
  int? _selectedMonth;
  GeminiDurationPreference? _selectedDurationPreference;

  String? _selectedCountryCode;
  GeminiTripPlan? _plan;
  String? _errorText;
  Map<String, _CountryOption> _countriesByCode =
      const <String, _CountryOption>{};

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
        title: const Text('AI Plan Editor'),
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
          final hasPreferredCityInput =
              !_noCities && _citiesController.text.trim().isNotEmpty;
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
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 6),
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
                        '2) Travel timing and stay duration',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 10),
                      SegmentedButton<_TimeInputMode>(
                        showSelectedIcon: false,
                        segments: const <ButtonSegment<_TimeInputMode>>[
                          ButtonSegment<_TimeInputMode>(
                            value: _TimeInputMode.aiRecommended,
                            icon: Icon(Icons.auto_awesome_outlined),
                            label: Text('AI decides'),
                          ),
                          ButtonSegment<_TimeInputMode>(
                            value: _TimeInputMode.preciseDates,
                            icon: Icon(Icons.date_range_outlined),
                            label: Text('Precise dates'),
                          ),
                          ButtonSegment<_TimeInputMode>(
                            value: _TimeInputMode.monthAndDuration,
                            icon: Icon(Icons.calendar_month_outlined),
                            label: Text('Month + duration'),
                          ),
                        ],
                        selected: <_TimeInputMode>{_timeInputMode},
                        onSelectionChanged: (selected) {
                          if (selected.isEmpty) {
                            return;
                          }
                          setState(() {
                            _timeInputMode = selected.first;
                            _errorText = null;
                            if (_timeInputMode != _TimeInputMode.preciseDates) {
                              _dateRange = null;
                            }
                            if (_timeInputMode !=
                                _TimeInputMode.monthAndDuration) {
                              _selectedMonth = null;
                              _selectedDurationPreference = null;
                            }
                          });
                        },
                      ),
                      if (_timeInputMode ==
                          _TimeInputMode.preciseDates) ...<Widget>[
                        const SizedBox(height: 8),
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
                            child:
                                Text(_dateRange == null ? 'Select' : 'Change'),
                          ),
                        ),
                      ],
                      if (_timeInputMode ==
                          _TimeInputMode.monthAndDuration) ...<Widget>[
                        const SizedBox(height: 10),
                        DropdownButtonFormField<int>(
                          value: _selectedMonth,
                          decoration: const InputDecoration(
                            labelText: 'Preferred month',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.calendar_today_outlined),
                          ),
                          items: <DropdownMenuItem<int>>[
                            for (var month = 1;
                                month <= DateTime.december;
                                month += 1)
                              DropdownMenuItem<int>(
                                value: month,
                                child: Text(_monthName(month)),
                              ),
                          ],
                          onChanged: (value) {
                            setState(() {
                              _selectedMonth = value;
                              _errorText = null;
                            });
                          },
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Choose your trip duration',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: <Widget>[
                            for (final option in geminiDurationPreferences)
                              ChoiceChip(
                                label: Text(
                                  '${option.label} (${option.minDays}-${option.maxDays}d)',
                                ),
                                selected: _selectedDurationPreference?.id ==
                                    option.id,
                                onSelected: (selected) {
                                  setState(() {
                                    _selectedDurationPreference =
                                        selected ? option : null;
                                    _errorText = null;
                                  });
                                },
                              ),
                          ],
                        ),
                      ],
                      if (_timeInputMode == _TimeInputMode.aiRecommended)
                        Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: Text(
                            'AI will recommend a practical travel month and duration.',
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                    ),
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
                            _errorText = null;
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
                            hintText: 'Madrid, Barcelona',
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (_) {
                            setState(() {
                              _errorText = null;
                            });
                          },
                        ),
                      if (hasPreferredCityInput) ...<Widget>[
                        const SizedBox(height: 8),
                        SwitchListTile(
                          value: _allowAdditionalCities,
                          contentPadding: EdgeInsets.zero,
                          title: const Text(
                            'Allow adding nearby cities when time allows',
                          ),
                          subtitle: const Text(
                            'AI may add 1-2 cities only if your schedule has enough room.',
                          ),
                          onChanged: (value) {
                            setState(() {
                              _allowAdditionalCities = value;
                              _errorText = null;
                            });
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed:
                    canGenerate ? () => _generatePlan(item, prefs) : null,
                icon: _isGenerating
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.auto_awesome_outlined),
                label:
                    Text(_isGenerating ? 'Generating...' : 'Generate AI Plan'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
              if (_errorText != null) ...<Widget>[
                const SizedBox(height: 10),
                Card(
                  color: Theme.of(context).colorScheme.errorContainer,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Icon(
                              Icons.error_outline,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onErrorContainer,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _errorText!,
                                style: TextStyle(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onErrorContainer,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            onPressed: canGenerate
                                ? () => _generatePlan(item, prefs)
                                : null,
                            icon: const Icon(Icons.refresh_outlined),
                            label: const Text('Try again'),
                          ),
                        ),
                      ],
                    ),
                  ),
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

    final seededCities = item.plannedCities?.trim();
    if (seededCities != null && seededCities.isNotEmpty) {
      _citiesController.text = seededCities;
      _noCities = false;
    } else {
      _noCities = true;
    }

    if (item.plannedStartDate != null && item.plannedEndDate != null) {
      _dateRange = DateTimeRange(
        start: DateTime.fromMillisecondsSinceEpoch(item.plannedStartDate!),
        end: DateTime.fromMillisecondsSinceEpoch(item.plannedEndDate!),
      );
      _timeInputMode = _TimeInputMode.preciseDates;
    } else {
      _timeInputMode = _TimeInputMode.aiRecommended;
    }

    _applyStoredRequestOptions(item.aiPlan);

    final existingPlan = _tryParseStoredPlan(item.aiPlan);
    if (existingPlan != null) {
      _plan = existingPlan;
    }

    _didHydrate = true;
  }

  void _applyStoredRequestOptions(String? rawPlan) {
    final raw = rawPlan?.trim();
    if (raw == null || raw.isEmpty) {
      return;
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return;
      }
      final request = decoded['request'];
      if (request is! Map<String, dynamic>) {
        return;
      }

      final modeRaw = (request['time_mode'] as String?)?.trim();
      switch (modeRaw) {
        case 'precise_dates':
          _timeInputMode = _TimeInputMode.preciseDates;
        case 'month_and_duration':
          _timeInputMode = _TimeInputMode.monthAndDuration;
          _dateRange = null;
        case 'ai_recommended':
          _timeInputMode = _TimeInputMode.aiRecommended;
          _dateRange = null;
      }

      final month = _readInt(request['preferred_month']);
      if (month != null && month >= 1 && month <= DateTime.december) {
        _selectedMonth = month;
      }

      final durationId = (request['duration_preference_id'] as String?)?.trim();
      if (durationId != null && durationId.isNotEmpty) {
        for (final option in geminiDurationPreferences) {
          if (option.id == durationId) {
            _selectedDurationPreference = option;
            break;
          }
        }
      }

      final allowExtra = _readBool(request['allow_extra_cities']);
      if (allowExtra != null) {
        _allowAdditionalCities = allowExtra;
      }
    } catch (_) {
      return;
    }
  }

  GeminiTripPlan? _tryParseStoredPlan(String? rawPlan) {
    final raw = rawPlan?.trim();
    if (raw == null || raw.isEmpty) {
      return null;
    }
    final planner = ref.read(geminiTripPlannerProvider);
    return planner.parseStoredPlan(
      raw,
      fallbackCountry: _resolveCountryName(),
    );
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
      if (option.name.toLowerCase() == query ||
          option.code.toLowerCase() == query) {
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
      _errorText = null;
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

    if (_timeInputMode == _TimeInputMode.preciseDates && _dateRange == null) {
      setState(() {
        _errorText = 'Please select a precise date range first.';
      });
      return;
    }

    if (_timeInputMode == _TimeInputMode.monthAndDuration) {
      if (_selectedMonth == null) {
        setState(() {
          _errorText = 'Please choose a preferred month.';
        });
        return;
      }
      if (_selectedDurationPreference == null) {
        setState(() {
          _errorText = 'Please choose one of the four duration options.';
        });
        return;
      }
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
      final generatedPlan = await planner.generatePlan(
        apiKey: prefs.geminiApiKey,
        countryName: countryName,
        homeBase: prefs.homeBase,
        preciseWindow:
            _timeInputMode == _TimeInputMode.preciseDates ? _dateRange : null,
        preferredMonth: _timeInputMode == _TimeInputMode.monthAndDuration
            ? _selectedMonth
            : null,
        durationPreference: _timeInputMode == _TimeInputMode.monthAndDuration
            ? _selectedDurationPreference
            : null,
        preferredCities: preferredCities,
        allowAdditionalCitiesIfTimeAllows:
            preferredCities.isNotEmpty && _allowAdditionalCities,
      );
      final mergedPlan = _plan == null
          ? generatedPlan
          : planner.mergePlans(
              current: _plan!,
              generated: generatedPlan,
            );
      final finalizedPlan = await planner.hydrateMissingCityImages(
        plan: mergedPlan,
        fallbackCountry: countryName,
      );

      setState(() {
        _plan = finalizedPlan;
      });

      await _saveDraft(item, plan: finalizedPlan);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('AI plan updated and saved.')),
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
              ...ref.read(geminiTripPlannerProvider).toStorageJson(plan),
              'request': _buildRequestPayload(),
            },
          );

    await ref.read(wishlistRepositoryProvider).updateWishlistItem(
          item.copyWith(
            countryName: countryName.isEmpty ? null : countryName,
            countryCode: _selectedCountryCode,
            plannedStartDate: _timeInputMode == _TimeInputMode.preciseDates
                ? _dateRange?.start.millisecondsSinceEpoch
                : null,
            plannedEndDate: _timeInputMode == _TimeInputMode.preciseDates
                ? _dateRange?.end.millisecondsSinceEpoch
                : null,
            plannedCities: plannedCities == null || plannedCities.isEmpty
                ? null
                : plannedCities,
            aiPlan: payload,
          ),
        );
  }

  Map<String, dynamic> _buildRequestPayload() {
    final payload = <String, dynamic>{
      'time_mode': switch (_timeInputMode) {
        _TimeInputMode.aiRecommended => 'ai_recommended',
        _TimeInputMode.preciseDates => 'precise_dates',
        _TimeInputMode.monthAndDuration => 'month_and_duration',
      },
      'allow_extra_cities': _allowAdditionalCities,
    };

    if (_timeInputMode == _TimeInputMode.monthAndDuration) {
      if (_selectedMonth != null) {
        payload['preferred_month'] = _selectedMonth;
      }
      if (_selectedDurationPreference != null) {
        payload['duration_preference_id'] = _selectedDurationPreference!.id;
      }
    }

    if (_timeInputMode == _TimeInputMode.preciseDates && _dateRange != null) {
      payload['precise_start'] = _dateRange!.start.millisecondsSinceEpoch;
      payload['precise_end'] = _dateRange!.end.millisecondsSinceEpoch;
    }

    return payload;
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

  String _monthName(int month) {
    const names = <String>[
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return names[month - 1];
  }

  int? _readInt(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.round();
    }
    if (value is String) {
      return int.tryParse(value.trim());
    }
    return null;
  }

  bool? _readBool(dynamic value) {
    if (value is bool) {
      return value;
    }
    if (value is num) {
      return value != 0;
    }
    if (value is! String) {
      return null;
    }
    final normalized = value.trim().toLowerCase();
    if (normalized == 'true' || normalized == '1' || normalized == 'yes') {
      return true;
    }
    if (normalized == 'false' || normalized == '0' || normalized == 'no') {
      return false;
    }
    return null;
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
                    'Generate a city-level plan, duration fit, and expandable city cards.',
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
    final detailByCity = <String, GeminiCityDetail>{
      for (final detail in plan.cityDetails) _cityKey(detail.city): detail,
    };

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
            if (plan.stayDuration != null) ...<Widget>[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: Theme.of(context).colorScheme.surfaceContainerHigh,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    CircleAvatar(
                      radius: 14,
                      child: Text('${plan.stayDuration!.days}d'),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            plan.stayDuration!.source == 'user_selected'
                                ? 'Duration matched to your preference'
                                : 'AI-recommended trip duration',
                            style: Theme.of(context).textTheme.labelLarge,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            plan.stayDuration!.reason,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
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
                      color:
                          Theme.of(context).colorScheme.surfaceContainerHighest,
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
                'City Cards',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 6),
              ...plan.cityPlan.map(
                (city) => _CityPlanCard(
                  city: city,
                  detail: detailByCity[_cityKey(city.city)],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CityPlanCard extends StatelessWidget {
  const _CityPlanCard({
    required this.city,
    required this.detail,
  });

  final GeminiCityPlan city;
  final GeminiCityDetail? detail;

  @override
  Widget build(BuildContext context) {
    final image = detail?.image;
    final timeline = detail?.timeline ?? const <GeminiTimelineStop>[];
    final things = detail?.thingsToDo ?? const <String>[];

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: <Widget>[
          if (image != null)
            SizedBox(
              height: 160,
              width: double.infinity,
              child: CachedNetworkImage(
                imageUrl: image.imageUrl,
                fit: BoxFit.cover,
                placeholder: (_, __) => const _CityImagePlaceholder(),
                errorWidget: (_, __, ___) => const _CityImagePlaceholder(),
              ),
            ),
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              leading: CircleAvatar(
                radius: 16,
                child: Text('${city.days}d'),
              ),
              title: Row(
                children: <Widget>[
                  Expanded(child: Text(city.city)),
                  if (city.isExtra)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        color: Theme.of(context).colorScheme.secondaryContainer,
                      ),
                      child: Text(
                        'Extra city',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSecondaryContainer,
                            ),
                      ),
                    ),
                ],
              ),
              subtitle: Text(city.reason),
              children: <Widget>[
                if ((detail?.overview ?? '').trim().isNotEmpty) ...<Widget>[
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      detail!.overview,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                if (timeline.isNotEmpty) ...<Widget>[
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Places timeline',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  const SizedBox(height: 8),
                  for (var i = 0; i < timeline.length; i += 1)
                    _TimelineDotItem(
                      stop: timeline[i],
                      isLast: i == timeline.length - 1,
                    ),
                  const SizedBox(height: 8),
                ],
                if (things.isNotEmpty) ...<Widget>[
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Things to do',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  const SizedBox(height: 8),
                  for (final item in things)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          const Padding(
                            padding: EdgeInsets.only(top: 2),
                            child: Icon(Icons.check_circle_outline, size: 15),
                          ),
                          const SizedBox(width: 8),
                          Expanded(child: Text(item)),
                        ],
                      ),
                    ),
                ],
                if (image != null) ...<Widget>[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      color: Theme.of(context).colorScheme.surfaceContainerHigh,
                    ),
                    child: Text(
                      'Image source: ${image.source} | ${image.license} | ${image.creator}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelineDotItem extends StatelessWidget {
  const _TimelineDotItem({
    required this.stop,
    required this.isLast,
  });

  final GeminiTimelineStop stop;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(
          width: 22,
          child: Column(
            children: <Widget>[
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  shape: BoxShape.circle,
                ),
              ),
              if (!isLast)
                Container(
                  width: 2,
                  height: 46,
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  stop.slot,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: 1),
                Text(
                  stop.place,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 2),
                Text(
                  stop.note,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _CityImagePlaceholder extends StatelessWidget {
  const _CityImagePlaceholder();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: <Color>[
            Theme.of(context).colorScheme.surfaceContainerHighest,
            Theme.of(context).colorScheme.surfaceContainer,
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: const Center(
        child: Icon(Icons.photo_camera_back_outlined),
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

enum _TimeInputMode {
  aiRecommended,
  preciseDates,
  monthAndDuration,
}

String _cityKey(String value) => value.trim().toLowerCase();
