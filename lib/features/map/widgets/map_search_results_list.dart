import 'package:flutter/material.dart';

import '../../search/search_models.dart';
import '../../search/widgets/search_result_card.dart';

class MapSearchResultsList extends StatelessWidget {
  const MapSearchResultsList({
    super.key,
    required this.results,
    required this.onSelect,
  });

  final List<CountrySearchEntry> results;
  final ValueChanged<CountrySearchEntry> onSelect;

  @override
  Widget build(BuildContext context) {
    if (results.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      children: <Widget>[
        const SizedBox(height: 10),
        ...results.asMap().entries.map((entry) {
          final index = entry.key;
          final result = entry.value;
          return Padding(
            padding:
                EdgeInsets.only(bottom: index == results.length - 1 ? 0 : 8),
            child: SearchResultCard(
              entry: result,
              onTap: () => onSelect(result),
            ),
          );
        }),
      ],
    );
  }
}
