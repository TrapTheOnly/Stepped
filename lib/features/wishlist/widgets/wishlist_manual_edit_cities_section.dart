import 'package:flutter/material.dart';

import '../wishlist_plan_manual_edit_models.dart';
import 'wishlist_manual_edit_city_card.dart';
import 'wishlist_manual_edit_common_widgets.dart';
import 'wishlist_editor_shell.dart';

class WishlistManualEditCitiesSection extends StatelessWidget {
  const WishlistManualEditCitiesSection({
    super.key,
    required this.cities,
    required this.onAddCity,
    required this.onErrorClear,
    required this.onMoveCity,
    required this.onDeleteCity,
    required this.onAddTimelineStep,
    required this.onMoveTimelineStep,
    required this.onEditTimelineStep,
    required this.onDeleteTimelineStep,
    required this.onAddThing,
    required this.onMoveThing,
    required this.onEditThing,
    required this.onDeleteThing,
    required this.onCityStateChanged,
  });

  final List<EditableCity> cities;
  final VoidCallback onAddCity;
  final VoidCallback onErrorClear;
  final void Function(int from, int to) onMoveCity;
  final ValueChanged<int> onDeleteCity;
  final void Function(EditableCity city) onAddTimelineStep;
  final void Function(EditableCity city, int from, int to) onMoveTimelineStep;
  final void Function(EditableCity city, int index) onEditTimelineStep;
  final void Function(EditableCity city, int index) onDeleteTimelineStep;
  final void Function(EditableCity city) onAddThing;
  final void Function(EditableCity city, int from, int to) onMoveThing;
  final void Function(EditableCity city, int index) onEditThing;
  final void Function(EditableCity city, int index) onDeleteThing;
  final VoidCallback onCityStateChanged;

  @override
  Widget build(BuildContext context) {
    return WishlistEditorSectionCard(
      title: 'Route details',
      subtitle:
          'Every city becomes its own card on the plan review page, so use this space to shape the stop, its story, and its daily flow.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          WishlistManualEditSectionHeader(title: 'Cities', onAdd: onAddCity),
          const SizedBox(height: 12),
          if (cities.isEmpty)
            const WishlistManualEditInlineHint(text: 'No cities yet.')
          else
            ...cities.asMap().entries.map((entry) {
              final index = entry.key;
              final city = entry.value;
              return WishlistManualEditCityCard(
                city: city,
                index: index,
                totalCities: cities.length,
                onErrorClear: onErrorClear,
                onMoveCity: onMoveCity,
                onDeleteCity: onDeleteCity,
                onAddTimelineStep: onAddTimelineStep,
                onMoveTimelineStep: onMoveTimelineStep,
                onEditTimelineStep: onEditTimelineStep,
                onDeleteTimelineStep: onDeleteTimelineStep,
                onAddThing: onAddThing,
                onMoveThing: onMoveThing,
                onEditThing: onEditThing,
                onDeleteThing: onDeleteThing,
                onCityStateChanged: onCityStateChanged,
              );
            }),
        ],
      ),
    );
  }
}
