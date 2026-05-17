import 'package:flutter/material.dart';

import '../../../widgets/frosted_squircle.dart';
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
    return ListenableBuilder(
      listenable: Listenable.merge(<Listenable>[controller, focusNode]),
      builder: (context, _) {
        final optionList = _matchingOptions(
          query: controller.text,
          options: options,
        );
        final showOptions =
            focusNode.hasFocus && controller.text.trim().isNotEmpty;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Material(
              color: Colors.transparent,
              child: FrostedSquircle(
                radius: 28,
                blurSigma: 14,
                color: Theme.of(context).colorScheme.surface
                    .withValues(alpha: 0.52),
                borderColor: Theme.of(context)
                    .colorScheme
                    .outlineVariant
                    .withValues(alpha: 0.12),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                child: Row(
                  children: <Widget>[
                    Icon(
                      Icons.search_rounded,
                      size: 20,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        key: fieldKey,
                        controller: controller,
                        focusNode: focusNode,
                        onChanged: onTyped,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Country',
                          hintText: 'Search country',
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          filled: false,
                          isDense: true,
                          contentPadding:
                              EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    if (controller.text.trim().isNotEmpty)
                      IconButton(
                        onPressed: () {
                          controller.clear();
                          onTyped('');
                          focusNode.requestFocus();
                        },
                        tooltip: 'Clear search',
                        icon: const Icon(Icons.close_rounded),
                      )
                    else
                      const SizedBox(width: 8),
                  ],
                ),
              ),
            ),
            if (showOptions) ...<Widget>[
              const SizedBox(height: 10),
              if (optionList.isEmpty)
                _CountrySearchEmptyState(query: controller.text.trim())
              else
                Column(
                  children: optionList
                      .asMap()
                      .entries
                      .map(
                        (entry) => Padding(
                          padding: EdgeInsets.only(
                            bottom: entry.key == optionList.length - 1 ? 0 : 8,
                          ),
                          child: _CountrySearchResultCard(
                            option: entry.value,
                            onTap: () {
                              controller.text = entry.value.name;
                              onSelected(entry.value);
                              focusNode.unfocus();
                            },
                          ),
                        ),
                      )
                      .toList(growable: false),
                ),
            ],
          ],
        );
      },
    );
  }
}

List<TripCountryOption> _matchingOptions({
  required String query,
  required List<TripCountryOption> options,
}) {
  final trimmed = query.trim().toLowerCase();
  if (trimmed.isEmpty) {
    return const <TripCountryOption>[];
  }

  final startsWith = <TripCountryOption>[];
  final contains = <TripCountryOption>[];
  for (final option in options) {
    final name = option.name.toLowerCase();
    final code = option.code.toLowerCase();
    if (name.startsWith(trimmed) || code.startsWith(trimmed)) {
      startsWith.add(option);
      continue;
    }
    if (name.contains(trimmed) || code.contains(trimmed)) {
      contains.add(option);
    }
  }

  return <TripCountryOption>[
    ...startsWith,
    ...contains,
  ].take(3).toList(growable: false);
}

class _CountrySearchResultCard extends StatelessWidget {
  const _CountrySearchResultCard({
    required this.option,
    required this.onTap,
  });

  final TripCountryOption option;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        customBorder: squircleShape(28),
        child: FrostedSquircle(
          radius: 28,
          blurSigma: 12,
          color: colorScheme.surface.withValues(alpha: 0.62),
          borderColor: colorScheme.outlineVariant.withValues(alpha: 0.10),
          shadowColor: colorScheme.primary.withValues(alpha: 0.06),
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Row(
            children: <Widget>[
              CountryFlag(
                iso2: option.code,
                width: 32,
                height: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  option.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                option.code,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CountrySearchEmptyState extends StatelessWidget {
  const _CountrySearchEmptyState({required this.query});

  final String query;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return FrostedSquircle(
      radius: 24,
      blurSigma: 10,
      color: colorScheme.surface.withValues(alpha: 0.5),
      borderColor: colorScheme.outlineVariant.withValues(alpha: 0.08),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Text(
        'No countries found for "$query".',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
      ),
    );
  }
}
