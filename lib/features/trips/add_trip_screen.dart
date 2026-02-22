import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../data/db/app_db.dart';
import '../../data/repositories/trips_repository.dart';

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
        ArgumentError('Country code, country name, and cities are required.'),
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
  final _countryCodeController = TextEditingController();
  final _countryNameController = TextEditingController();
  final _citiesController = TextEditingController();
  final _coverImageController = TextEditingController();
  final _notesController = TextEditingController();

  DateTime? _startDate;
  DateTime? _endDate;
  bool _populatedFromExisting = false;

  @override
  void dispose() {
    _countryCodeController.dispose();
    _countryNameController.dispose();
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

          return SafeArea(
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: <Widget>[
                  TextFormField(
                    controller: _countryCodeController,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(labelText: 'Country Code'),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Required';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _countryNameController,
                    decoration: const InputDecoration(labelText: 'Country Name'),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Required';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  _DatePickerRow(
                    label: 'Start Date',
                    value: _startDate,
                    onPick: () => _pickDate(isStart: true),
                  ),
                  const SizedBox(height: 12),
                  _DatePickerRow(
                    label: 'End Date',
                    value: _endDate,
                    onPick: () => _pickDate(isStart: false),
                  ),
                  if (_startDate == null || _endDate == null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
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
                    decoration: const InputDecoration(labelText: 'Cities'),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Required';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _coverImageController,
                    decoration: const InputDecoration(
                      labelText: 'Cover Image URL or File Path',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _notesController,
                    maxLines: 3,
                    decoration: const InputDecoration(labelText: 'Notes'),
                  ),
                  const SizedBox(height: 20),
                  if (submitState.hasError)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        '${submitState.error}',
                        style: TextStyle(color: Theme.of(context).colorScheme.error),
                      ),
                    ),
                  FilledButton(
                    onPressed: submitState.isLoading ? null : _submit,
                    child: submitState.isLoading
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(widget.tripId == null ? 'Save Trip' : 'Update Trip'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _populateFromExisting(TripRecord trip) {
    _countryCodeController.text = trip.countryCode;
    _countryNameController.text = trip.countryName;
    _citiesController.text = trip.cities;
    _coverImageController.text = trip.coverImageUri ?? '';
    _notesController.text = trip.notes ?? '';
    _startDate = DateTime.fromMillisecondsSinceEpoch(trip.startDate);
    _endDate = DateTime.fromMillisecondsSinceEpoch(trip.endDate);
    _populatedFromExisting = true;
  }

  Future<void> _pickDate({required bool isStart}) async {
    final now = DateTime.now();
    final initialDate = isStart ? (_startDate ?? now) : (_endDate ?? _startDate ?? now);

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

  Future<void> _submit() async {
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid || _startDate == null || _endDate == null) {
      setState(() {});
      return;
    }

    final success = await ref.read(addTripControllerProvider.notifier).submit(
          tripId: widget.tripId,
          countryCode: _countryCodeController.text,
          countryName: _countryNameController.text,
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

class _DatePickerRow extends StatelessWidget {
  const _DatePickerRow({
    required this.label,
    required this.value,
    required this.onPick,
  });

  final String label;
  final DateTime? value;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final formatter = DateFormat('MMM d, y');

    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            '$label: ${value == null ? 'Not set' : formatter.format(value!)}',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
        OutlinedButton(
          onPressed: onPick,
          child: const Text('Pick'),
        ),
      ],
    );
  }
}
