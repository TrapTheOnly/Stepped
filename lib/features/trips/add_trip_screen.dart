import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'add_trip_controller.dart';
import 'add_trip_form_types.dart';
import 'add_trip_logic.dart';
import '../../data/db/app_db.dart';
import '../../data/repositories/trips_repository.dart';
import '../map/map_viewmodel.dart';
import 'widgets/add_trip_destination_preview.dart';
import 'widgets/add_trip_form_sections.dart';

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
  Map<String, TripCountryOption> _countryByCode =
      const <String, TripCountryOption>{};

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

          final countries = buildTripCountryOptions(
            countryDataset.countries,
            existingTrip: existingTrip,
            selectedCountryCode: _selectedCountryCode,
            selectedCountryName: _selectedCountryName,
          );
          _countryByCode = <String, TripCountryOption>{
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

          final inputTheme = roundedTripInputDecorationTheme(context);

          return Theme(
            data: Theme.of(context).copyWith(inputDecorationTheme: inputTheme),
            child: SafeArea(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 96),
                children: <Widget>[
                  AddTripDestinationPreview(
                    countryCode: _selectedCountryCode,
                    countryName: _selectedCountryName,
                  ),
                  const SizedBox(height: 16),
                  AddTripDestinationSection(
                    formKey: _formKey,
                    countryFieldKey: _countryFieldKey,
                    countryFocusNode: _countryFocusNode,
                    countrySearchController: _countrySearchController,
                    countries: countries,
                    countryValidationError: _countryValidationError,
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
                  const SizedBox(height: 12),
                  AddTripTravelDetailsSection(
                    startDate: _startDate,
                    endDate: _endDate,
                    citiesController: _citiesController,
                    onPickStartDate: () => _pickDate(isStart: true),
                    onPickEndDate: () => _pickDate(isStart: false),
                  ),
                  const SizedBox(height: 12),
                  AddTripMediaNotesSection(
                    coverImageController: _coverImageController,
                    notesController: _notesController,
                    onCoverImageChanged: (_) => setState(() {}),
                    onPickCoverImageFromDevice: _pickCoverImageFromDevice,
                    onClearCoverImage: () {
                      _coverImageController.clear();
                      setState(() {});
                    },
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
