import 'dart:async';
import 'dart:math' as math;
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../data/db/app_db.dart';
import '../../data/repositories/trips_repository.dart';
import '../../widgets/country_flag.dart';
import '../map/globe/globe_country_data.dart';
import '../map/map_viewmodel.dart';

final addTripControllerProvider =
    AutoDisposeAsyncNotifierProvider<AddTripController, void>(
  AddTripController.new,
);

class AddTripController extends AutoDisposeAsyncNotifier<void> {
  late final TripsRepository _repository;

  @override
  FutureOr<void> build() {
    _repository = ref.read(tripsRepositoryProvider);
  }

  Future<bool> submit({
    int? tripId,
    required String countryCode,
    required String countryName,
    required DateTime startDate,
    required DateTime endDate,
    required String cities,
    String? coverImageUri,
    String? notes,
  }) async {
    if (countryCode.trim().isEmpty ||
        countryName.trim().isEmpty ||
        cities.trim().isEmpty) {
      state = AsyncValue.error(
        ArgumentError('Country and cities are required.'),
        StackTrace.current,
      );
      return false;
    }

    if (endDate.isBefore(startDate)) {
      state = AsyncValue.error(
        ArgumentError('End date cannot be before start date.'),
        StackTrace.current,
      );
      return false;
    }

    state = const AsyncLoading();
    final trip = TripRecord(
      id: tripId,
      countryCode: countryCode.trim().toUpperCase(),
      countryName: countryName.trim(),
      startDate: startDate.millisecondsSinceEpoch,
      endDate: endDate.millisecondsSinceEpoch,
      cities: cities.trim(),
      coverImageUri: _nullableTrim(coverImageUri),
      notes: _nullableTrim(notes),
    );

    try {
      if (tripId == null) {
        await _repository.addTrip(trip);
      } else {
        await _repository.updateTrip(trip);
      }
      state = const AsyncData(null);
      return true;
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
      return false;
    }
  }

  String? _nullableTrim(String? value) {
    if (value == null) {
      return null;
    }
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}

class AddTripScreen extends ConsumerStatefulWidget {
  const AddTripScreen({super.key, this.tripId});

  final int? tripId;

  @override
  ConsumerState<AddTripScreen> createState() => _AddTripScreenState();
}

class _AddTripScreenState extends ConsumerState<AddTripScreen> {
  final _formKey = GlobalKey<FormState>();
  final _countryFieldKey = GlobalKey();
  final _countrySearchController = TextEditingController();
  final _countryFocusNode = FocusNode();
  final _citiesController = TextEditingController();
  final _coverImageController = TextEditingController();
  final _notesController = TextEditingController();

  DateTime? _startDate;
  DateTime? _endDate;
  bool _populatedFromExisting = false;
  String? _selectedCountryCode;
  String? _selectedCountryName;
  String? _countryValidationError;
  Map<String, _CountryOption> _countryByCode = const <String, _CountryOption>{};

  @override
  void dispose() {
    _countrySearchController.dispose();
    _countryFocusNode.dispose();
    _citiesController.dispose();
    _coverImageController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final existingTripAsync = widget.tripId == null
        ? const AsyncValue<TripRecord?>.data(null)
        : ref.watch(tripByIdProvider(widget.tripId!));
    final countriesAsync = ref.watch(globeCountryDatasetProvider);
    final submitState = ref.watch(addTripControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.tripId == null ? 'Add Trip' : 'Edit Trip'),
      ),
      body: existingTripAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Failed to load trip: $error')),
        data: (existingTrip) {
          if (widget.tripId != null && existingTrip == null) {
            return const Center(child: Text('Trip not found.'));
          }

          if (!_populatedFromExisting && existingTrip != null) {
            _populateFromExisting(existingTrip);
          }

          if (countriesAsync.hasError) {
            return Center(
              child: Text('Failed to load countries: ${countriesAsync.error}'),
            );
          }
          final countryDataset = countriesAsync.valueOrNull;
          if (countryDataset == null) {
            return const Center(child: CircularProgressIndicator());
          }

          final countries = _buildCountryOptions(
            countryDataset.countries,
            existingTrip: existingTrip,
          );
          _countryByCode = <String, _CountryOption>{
            for (final country in countries) country.code: country,
          };

          if (_selectedCountryCode != null &&
              _countrySearchController.text.isEmpty) {
            final selected = _countryByCode[_selectedCountryCode!];
            if (selected != null) {
              _selectedCountryName ??= selected.name;
              _countrySearchController.text = selected.name;
            }
          }

          final inputTheme = _roundedInputDecorationTheme(context);

          return Theme(
            data: Theme.of(context).copyWith(inputDecorationTheme: inputTheme),
            child: SafeArea(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 96),
                children: <Widget>[
                  _DestinationPreview(
                    countryCode: _selectedCountryCode,
                    countryName: _selectedCountryName,
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              'Destination',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 10),
                            _CountryAutocompleteField(
                              fieldKey: _countryFieldKey,
                              focusNode: _countryFocusNode,
                              controller: _countrySearchController,
                              options: countries,
                              selectedCountryName: _selectedCountryName,
                              onTyped: (value) {
                                final selected = _selectedCountryName;
                                if (selected != null &&
                                    value.trim().toLowerCase() !=
                                        selected.trim().toLowerCase()) {
                                  setState(() {
                                    _selectedCountryCode = null;
                                    _selectedCountryName = null;
                                  });
                                }
                                if (_countryValidationError != null &&
                                    value.trim().isNotEmpty) {
                                  setState(() {
                                    _countryValidationError = null;
                                  });
                                }
                              },
                              onSelected: (country) {
                                setState(() {
                                  _selectedCountryCode = country.code;
                                  _selectedCountryName = country.name;
                                  _countryValidationError = null;
                                  _countrySearchController.text = country.name;
                                });
                              },
                            ),
                            if (_countryValidationError != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 8, left: 4),
                                child: Text(
                                  _countryValidationError!,
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.error,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'Travel Details',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: <Widget>[
                              Expanded(
                                child: _DateField(
                                  label: 'Start date',
                                  value: _startDate,
                                  onTap: () => _pickDate(isStart: true),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _DateField(
                                  label: 'End date',
                                  value: _endDate,
                                  onTap: () => _pickDate(isStart: false),
                                ),
                              ),
                            ],
                          ),
                          if (_startDate == null || _endDate == null)
                            Padding(
                              padding: const EdgeInsets.only(top: 8, left: 4),
                              child: Text(
                                'Start and end dates are required.',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.error,
                                ),
                              ),
                            ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _citiesController,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: 'Cities',
                              hintText: 'Istanbul, Ankara',
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Required';
                              }
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'Media & Notes',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 10),
                          TextFormField(
                            controller: _coverImageController,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: 'Cover image URL or file path',
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: <Widget>[
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _pickCoverImageFromDevice,
                                  icon: const Icon(Icons.upload_file),
                                  label: const Text('Upload image'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              TextButton(
                                onPressed:
                                    _coverImageController.text.trim().isEmpty
                                        ? null
                                        : () {
                                            _coverImageController.clear();
                                            setState(() {});
                                          },
                                child: const Text('Clear'),
                              ),
                            ],
                          ),
                          if (_coverImageController.text
                              .trim()
                              .isNotEmpty) ...<Widget>[
                            const SizedBox(height: 10),
                            _CoverImagePreview(
                              uri: _coverImageController.text.trim(),
                            ),
                          ],
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _notesController,
                            minLines: 3,
                            maxLines: 5,
                            decoration:
                                const InputDecoration(labelText: 'Notes'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (submitState.hasError)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        '${submitState.error}',
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.error),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: FilledButton(
          onPressed: submitState.isLoading ? null : _submit,
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(56),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
          child: submitState.isLoading
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(widget.tripId == null ? 'Save Trip' : 'Update Trip'),
        ),
      ),
    );
  }

  InputDecorationTheme _roundedInputDecorationTheme(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: BorderSide(color: scheme.outlineVariant),
    );
    return InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
      border: border,
      enabledBorder: border,
      focusedBorder: border.copyWith(
        borderSide: BorderSide(color: scheme.primary, width: 1.4),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    );
  }

  List<_CountryOption> _buildCountryOptions(
    List<GlobeCountryShape> countries, {
    TripRecord? existingTrip,
  }) {
    final byCode = <String, _CountryOption>{
      for (final country in countries)
        country.iso2.toUpperCase(): _CountryOption(
          code: country.iso2.toUpperCase(),
          name: country.name,
        ),
      for (final country in _microstatesSearchOnly) country.code: country,
    };

    if (existingTrip != null) {
      final code = existingTrip.countryCode.toUpperCase();
      byCode.putIfAbsent(
        code,
        () => _CountryOption(
          code: code,
          name: existingTrip.countryName,
        ),
      );
    }

    if (_selectedCountryCode != null && _selectedCountryName != null) {
      final code = _selectedCountryCode!.toUpperCase();
      byCode.putIfAbsent(
        code,
        () => _CountryOption(
          code: code,
          name: _selectedCountryName!,
        ),
      );
    }

    final options = byCode.values.toList(growable: false)
      ..sort((left, right) => left.name.compareTo(right.name));
    return options;
  }

  void _populateFromExisting(TripRecord trip) {
    _selectedCountryCode = trip.countryCode.toUpperCase();
    _selectedCountryName = trip.countryName;
    _countrySearchController.text = trip.countryName;
    _citiesController.text = trip.cities;
    _coverImageController.text = trip.coverImageUri ?? '';
    _notesController.text = trip.notes ?? '';
    _startDate = DateTime.fromMillisecondsSinceEpoch(trip.startDate);
    _endDate = DateTime.fromMillisecondsSinceEpoch(trip.endDate);
    _populatedFromExisting = true;
  }

  Future<void> _pickDate({required bool isStart}) async {
    final now = DateTime.now();
    final initialDate =
        isStart ? (_startDate ?? now) : (_endDate ?? _startDate ?? now);

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1970),
      lastDate: DateTime(now.year + 10),
    );

    if (picked == null) {
      return;
    }

    setState(() {
      if (isStart) {
        _startDate = picked;
        if (_endDate != null && _endDate!.isBefore(picked)) {
          _endDate = picked;
        }
      } else {
        _endDate = picked;
      }
    });
  }

  Future<void> _pickCoverImageFromDevice() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
      withData: false,
    );
    if (!mounted || result == null || result.files.isEmpty) {
      return;
    }

    final path = result.files.single.path;
    if (path == null || path.trim().isEmpty) {
      return;
    }

    _coverImageController.text = path.trim();
    setState(() {});
  }

  Future<void> _submit() async {
    final isValid = _formKey.currentState?.validate() ?? false;
    final selectedCountryCode = _selectedCountryCode?.trim().toUpperCase();
    final selectedCountryName = selectedCountryCode == null
        ? null
        : _countryByCode[selectedCountryCode]?.name ?? _selectedCountryName;

    if (!isValid || _startDate == null || _endDate == null) {
      setState(() {});
      return;
    }

    if (selectedCountryCode == null ||
        selectedCountryCode.isEmpty ||
        selectedCountryName == null ||
        selectedCountryName.trim().isEmpty) {
      setState(() {
        _countryValidationError = 'Required';
      });
      return;
    }

    final success = await ref.read(addTripControllerProvider.notifier).submit(
          tripId: widget.tripId,
          countryCode: selectedCountryCode,
          countryName: selectedCountryName,
          startDate: _startDate!,
          endDate: _endDate!,
          cities: _citiesController.text,
          coverImageUri: _coverImageController.text,
          notes: _notesController.text,
        );

    if (!mounted || !success) {
      return;
    }

    context.pop();
  }
}

class _CoverImagePreview extends StatelessWidget {
  const _CoverImagePreview({required this.uri});

  final String uri;

  @override
  Widget build(BuildContext context) {
    final normalized = uri.trim();
    Widget content;

    if (normalized.startsWith('http://') || normalized.startsWith('https://')) {
      content = Image.network(
        normalized,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const _CoverPlaceholder(),
        loadingBuilder: (context, child, progress) {
          if (progress == null) {
            return child;
          }
          return const _CoverPlaceholder();
        },
      );
    } else {
      final localPath = normalized.startsWith('file://')
          ? normalized.replaceFirst('file://', '')
          : normalized;
      final file = File(localPath);
      content = file.existsSync()
          ? Image.file(file, fit: BoxFit.cover)
          : const _CoverPlaceholder();
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        height: 140,
        width: double.infinity,
        child: ColoredBox(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: content,
        ),
      ),
    );
  }
}

class _CoverPlaceholder extends StatelessWidget {
  const _CoverPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Icon(
        Icons.image_not_supported_outlined,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}

class _DestinationPreview extends StatelessWidget {
  const _DestinationPreview({
    required this.countryCode,
    required this.countryName,
  });

  final String? countryCode;
  final String? countryName;

  @override
  Widget build(BuildContext context) {
    final width = math.min(MediaQuery.sizeOf(context).width * 0.5, 220.0);
    final height = width * 0.75;
    final scheme = Theme.of(context).colorScheme;

    return Column(
      children: <Widget>[
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          child: countryCode == null
              ? Container(
                  key: const ValueKey<String>('globe'),
                  width: width,
                  height: height,
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(
                    Icons.public,
                    size: width * 0.42,
                    color: scheme.onSurfaceVariant,
                  ),
                )
              : CountryFlag(
                  key: ValueKey<String>(countryCode!),
                  iso2: countryCode!,
                  width: width,
                  height: height,
                  borderRadius: 20,
                ),
        ),
        const SizedBox(height: 10),
        Text(
          countryName ?? 'Choose a destination',
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ],
    );
  }
}

class _CountryAutocompleteField extends StatelessWidget {
  const _CountryAutocompleteField({
    required this.fieldKey,
    required this.focusNode,
    required this.controller,
    required this.options,
    required this.selectedCountryName,
    required this.onTyped,
    required this.onSelected,
  });

  final GlobalKey fieldKey;
  final FocusNode focusNode;
  final TextEditingController controller;
  final List<_CountryOption> options;
  final String? selectedCountryName;
  final ValueChanged<String> onTyped;
  final ValueChanged<_CountryOption> onSelected;

  @override
  Widget build(BuildContext context) {
    return RawAutocomplete<_CountryOption>(
      textEditingController: controller,
      focusNode: focusNode,
      displayStringForOption: (option) => option.name,
      optionsBuilder: (textEditingValue) {
        final query = textEditingValue.text.trim().toLowerCase();
        if (query.isEmpty) {
          return options.take(40);
        }

        final startsWith = <_CountryOption>[];
        final contains = <_CountryOption>[];
        for (final option in options) {
          final name = option.name.toLowerCase();
          final code = option.code.toLowerCase();
          if (name.startsWith(query) || code.startsWith(query)) {
            startsWith.add(option);
            continue;
          }
          if (name.contains(query) || code.contains(query)) {
            contains.add(option);
          }
        }

        return <_CountryOption>[
          ...startsWith,
          ...contains,
        ];
      },
      onSelected: onSelected,
      fieldViewBuilder: (
        context,
        textEditingController,
        focusNode,
        onFieldSubmitted,
      ) {
        return TextFormField(
          key: fieldKey,
          controller: textEditingController,
          focusNode: focusNode,
          decoration: const InputDecoration(
            labelText: 'Country',
            hintText: 'Search country',
            prefixIcon: Icon(Icons.search),
          ),
          onChanged: onTyped,
          textInputAction: TextInputAction.next,
        );
      },
      optionsViewBuilder: (context, onSelected, optionsIterable) {
        final optionList = optionsIterable.toList(growable: false);
        if (optionList.isEmpty) {
          return const SizedBox.shrink();
        }

        final renderBox =
            fieldKey.currentContext?.findRenderObject() as RenderBox?;
        final width = renderBox?.size.width ??
            (MediaQuery.sizeOf(context).width - 32).clamp(280.0, 720.0);
        final visibleCount = optionList.length.clamp(1, 6);
        final maxHeight = (visibleCount * 56.0) + 8.0;

        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(16),
            clipBehavior: Clip.antiAlias,
            child: SizedBox(
              width: width.toDouble(),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: maxHeight.toDouble()),
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  itemCount: optionList.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final option = optionList[index];
                    return InkWell(
                      onTap: () => onSelected(option),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        child: Row(
                          children: <Widget>[
                            CountryFlag(
                              iso2: option.code,
                              width: 24,
                              height: 18,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                option.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              option.code,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final DateTime? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final formatter = DateFormat('MMM d, y');
    final borderColor = Theme.of(context).colorScheme.outlineVariant;

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: borderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              label,
              style: Theme.of(context).textTheme.labelMedium,
            ),
            const SizedBox(height: 4),
            Row(
              children: <Widget>[
                const Icon(Icons.calendar_month, size: 16),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    value == null ? 'Not set' : formatter.format(value!),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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

class _CountryOption {
  const _CountryOption({
    required this.code,
    required this.name,
  });

  final String code;
  final String name;
}

const _microstatesSearchOnly = <_CountryOption>[
  _CountryOption(code: 'AD', name: 'Andorra'),
  _CountryOption(code: 'LI', name: 'Liechtenstein'),
  _CountryOption(code: 'MC', name: 'Monaco'),
  _CountryOption(code: 'SM', name: 'San Marino'),
  _CountryOption(code: 'VA', name: 'Vatican City'),
];
