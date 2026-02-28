import 'package:flutter/material.dart';

import '../../../widgets/country_flag.dart';
import '../add_trip_form_types.dart';

class AddTripCountryAutocompleteField extends StatelessWidget {
  const AddTripCountryAutocompleteField({
    super.key,
    required this.fieldKey,
    required this.focusNode,
    required this.controller,
    required this.options,
    required this.onTyped,
    required this.onSelected,
  });

  final GlobalKey fieldKey;
  final FocusNode focusNode;
  final TextEditingController controller;
  final List<TripCountryOption> options;
  final ValueChanged<String> onTyped;
  final ValueChanged<TripCountryOption> onSelected;

  @override
  Widget build(BuildContext context) {
    return RawAutocomplete<TripCountryOption>(
      textEditingController: controller,
      focusNode: focusNode,
      displayStringForOption: (option) => option.name,
      optionsBuilder: (textEditingValue) {
        final query = textEditingValue.text.trim().toLowerCase();
        if (query.isEmpty) {
          return options.take(40);
        }

        final startsWith = <TripCountryOption>[];
        final contains = <TripCountryOption>[];
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

        return <TripCountryOption>[
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
