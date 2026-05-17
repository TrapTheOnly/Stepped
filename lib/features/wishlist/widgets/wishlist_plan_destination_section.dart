import 'package:flutter/material.dart';

import '../wishlist_plan_form_types.dart';
import 'wishlist_editor_shell.dart';
import 'wishlist_country_autocomplete_field.dart';

class WishlistPlanDestinationSection extends StatelessWidget {
  const WishlistPlanDestinationSection({
    super.key,
    required this.datasetIsLoading,
    required this.datasetError,
    required this.options,
    required this.countryController,
    required this.countryFocusNode,
    required this.onCountrySelected,
    required this.onCountryInputChanged,
  });

  final bool datasetIsLoading;
  final Object? datasetError;
  final List<WishlistCountryOption> options;
  final TextEditingController countryController;
  final FocusNode countryFocusNode;
  final ValueChanged<WishlistCountryOption> onCountrySelected;
  final ValueChanged<String> onCountryInputChanged;

  @override
  Widget build(BuildContext context) {
    return WishlistEditorSectionCard(
      title: 'Destination',
      subtitle:
          'Choose the country first. Cities can stay flexible if you want AI to discover the route.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (datasetIsLoading) const LinearProgressIndicator(minHeight: 2),
          if (datasetError != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'Country list unavailable: $datasetError',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ),
          WishlistCountryAutocompleteField(
            focusNode: countryFocusNode,
            controller: countryController,
            options: options,
            onTyped: onCountryInputChanged,
            onSelected: onCountrySelected,
          ),
        ],
      ),
    );
  }
}
