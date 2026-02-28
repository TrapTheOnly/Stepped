import 'package:flutter/material.dart';

import '../add_trip_form_types.dart';
import 'add_trip_country_autocomplete_field.dart';
import 'add_trip_cover_image_preview.dart';
import 'add_trip_date_field.dart';

class AddTripDestinationSection extends StatelessWidget {
  const AddTripDestinationSection({
    super.key,
    required this.formKey,
    required this.countryFieldKey,
    required this.countryFocusNode,
    required this.countrySearchController,
    required this.countries,
    required this.countryValidationError,
    required this.onTyped,
    required this.onSelected,
  });

  final GlobalKey<FormState> formKey;
  final GlobalKey countryFieldKey;
  final FocusNode countryFocusNode;
  final TextEditingController countrySearchController;
  final List<TripCountryOption> countries;
  final String? countryValidationError;
  final ValueChanged<String> onTyped;
  final ValueChanged<TripCountryOption> onSelected;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Destination',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 10),
              AddTripCountryAutocompleteField(
                fieldKey: countryFieldKey,
                focusNode: countryFocusNode,
                controller: countrySearchController,
                options: countries,
                onTyped: onTyped,
                onSelected: onSelected,
              ),
              if (countryValidationError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8, left: 4),
                  child: Text(
                    countryValidationError!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class AddTripTravelDetailsSection extends StatelessWidget {
  const AddTripTravelDetailsSection({
    super.key,
    required this.startDate,
    required this.endDate,
    required this.citiesController,
    required this.onPickStartDate,
    required this.onPickEndDate,
  });

  final DateTime? startDate;
  final DateTime? endDate;
  final TextEditingController citiesController;
  final VoidCallback onPickStartDate;
  final VoidCallback onPickEndDate;

  @override
  Widget build(BuildContext context) {
    return Card(
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
                  child: AddTripDateField(
                    label: 'Start date',
                    value: startDate,
                    onTap: onPickStartDate,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: AddTripDateField(
                    label: 'End date',
                    value: endDate,
                    onTap: onPickEndDate,
                  ),
                ),
              ],
            ),
            if (startDate == null || endDate == null)
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
              controller: citiesController,
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
    );
  }
}

class AddTripMediaNotesSection extends StatelessWidget {
  const AddTripMediaNotesSection({
    super.key,
    required this.coverImageController,
    required this.notesController,
    required this.onCoverImageChanged,
    required this.onPickCoverImageFromDevice,
    required this.onClearCoverImage,
  });

  final TextEditingController coverImageController;
  final TextEditingController notesController;
  final ValueChanged<String> onCoverImageChanged;
  final VoidCallback onPickCoverImageFromDevice;
  final VoidCallback onClearCoverImage;

  @override
  Widget build(BuildContext context) {
    return Card(
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
              controller: coverImageController,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Cover image URL or file path',
              ),
              onChanged: onCoverImageChanged,
            ),
            const SizedBox(height: 8),
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onPickCoverImageFromDevice,
                    icon: const Icon(Icons.upload_file),
                    label: const Text('Upload image'),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: coverImageController.text.trim().isEmpty
                      ? null
                      : onClearCoverImage,
                  child: const Text('Clear'),
                ),
              ],
            ),
            if (coverImageController.text.trim().isNotEmpty) ...<Widget>[
              const SizedBox(height: 10),
              AddTripCoverImagePreview(uri: coverImageController.text.trim()),
            ],
            const SizedBox(height: 12),
            TextFormField(
              controller: notesController,
              minLines: 3,
              maxLines: 5,
              decoration: const InputDecoration(labelText: 'Notes'),
            ),
          ],
        ),
      ),
    );
  }
}
