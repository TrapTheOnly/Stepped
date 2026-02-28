import 'package:flutter/material.dart';

import '../../../widgets/country_flag.dart';
import '../wishlist_plan_form_types.dart';

class WishlistPlanDestinationSection extends StatelessWidget {
  const WishlistPlanDestinationSection({
    super.key,
    required this.datasetIsLoading,
    required this.datasetError,
    required this.options,
    required this.countryController,
    required this.countryFocusNode,
    required this.selectedCountryCode,
    required this.selectedCountryName,
    required this.onCountrySelected,
    required this.onCountryInputChanged,
  });

  final bool datasetIsLoading;
  final Object? datasetError;
  final List<WishlistCountryOption> options;
  final TextEditingController countryController;
  final FocusNode countryFocusNode;
  final String? selectedCountryCode;
  final String selectedCountryName;
  final ValueChanged<WishlistCountryOption> onCountrySelected;
  final ValueChanged<String> onCountryInputChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
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
            RawAutocomplete<WishlistCountryOption>(
              textEditingController: countryController,
              focusNode: countryFocusNode,
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
              onSelected: onCountrySelected,
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
                  onChanged: onCountryInputChanged,
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
                  if (selectedCountryCode != null)
                    CountryFlag(
                      iso2: selectedCountryCode!,
                      width: 28,
                      height: 20,
                    ),
                  if (selectedCountryCode != null) const SizedBox(width: 8),
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
    );
  }
}
