import 'package:flutter/material.dart';

import '../wishlist_plan_manual_edit_models.dart';
import 'wishlist_manual_edit_common_widgets.dart';

class WishlistManualEditCityCard extends StatelessWidget {
  const WishlistManualEditCityCard({
    super.key,
    required this.city,
    required this.index,
    required this.totalCities,
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

  final EditableCity city;
  final int index;
  final int totalCities;
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
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    city.city.trim().isEmpty ? 'Untitled city' : city.city,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                IconButton(
                  tooltip: 'Move up',
                  onPressed: index == 0 ? null : () => onMoveCity(index, index - 1),
                  icon: const Icon(Icons.keyboard_arrow_up),
                ),
                IconButton(
                  tooltip: 'Move down',
                  onPressed: index == totalCities - 1
                      ? null
                      : () => onMoveCity(index, index + 1),
                  icon: const Icon(Icons.keyboard_arrow_down),
                ),
                IconButton(
                  tooltip: 'Delete city',
                  onPressed: () => onDeleteCity(index),
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextFormField(
              initialValue: city.city,
              decoration: const InputDecoration(
                labelText: 'City',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                city.city = value;
                onErrorClear();
              },
            ),
            const SizedBox(height: 8),
            Row(
              children: <Widget>[
                Expanded(
                  child: TextFormField(
                    initialValue: city.days.toString(),
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Days',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) {
                      city.days = int.tryParse(value.trim()) ?? city.days;
                      onErrorClear();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SwitchListTile(
                    value: city.isExtra,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Extra city'),
                    onChanged: (value) {
                      city.isExtra = value;
                      onCityStateChanged();
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextFormField(
              initialValue: city.reason,
              decoration: const InputDecoration(
                labelText: 'Reason',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                city.reason = value;
                onErrorClear();
              },
            ),
            const SizedBox(height: 8),
            TextFormField(
              initialValue: city.overview,
              minLines: 1,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Overview',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                city.overview = value;
                onErrorClear();
              },
            ),
            const SizedBox(height: 8),
            TextFormField(
              initialValue: city.imageQuery,
              decoration: const InputDecoration(
                labelText: 'Image query',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                city.imageQuery = value;
                onErrorClear();
              },
            ),
            if (city.image != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Current image: ${city.image!.source} | ${city.image!.license}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            const SizedBox(height: 10),
            WishlistManualEditSubSectionHeader(
              title: 'Timeline',
              onAdd: () => onAddTimelineStep(city),
            ),
            const SizedBox(height: 6),
            if (city.timeline.isEmpty)
              const WishlistManualEditMutedHint(text: 'No timeline steps for this city.'),
            ...city.timeline.asMap().entries.map((timelineEntry) {
              final timelineIndex = timelineEntry.key;
              final timeline = timelineEntry.value;
              return ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text('${timeline.slot} -> ${timeline.place}'),
                subtitle: Text(timeline.note),
                trailing: Wrap(
                  spacing: 2,
                  children: <Widget>[
                    IconButton(
                      tooltip: 'Move up',
                      onPressed: timelineIndex == 0
                          ? null
                          : () => onMoveTimelineStep(
                                city,
                                timelineIndex,
                                timelineIndex - 1,
                              ),
                      icon: const Icon(Icons.keyboard_arrow_up),
                    ),
                    IconButton(
                      tooltip: 'Move down',
                      onPressed: timelineIndex == city.timeline.length - 1
                          ? null
                          : () => onMoveTimelineStep(
                                city,
                                timelineIndex,
                                timelineIndex + 1,
                              ),
                      icon: const Icon(Icons.keyboard_arrow_down),
                    ),
                    IconButton(
                      tooltip: 'Edit',
                      onPressed: () => onEditTimelineStep(city, timelineIndex),
                      icon: const Icon(Icons.edit_outlined),
                    ),
                    IconButton(
                      tooltip: 'Delete',
                      onPressed: () => onDeleteTimelineStep(city, timelineIndex),
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 10),
            WishlistManualEditSubSectionHeader(
              title: 'Things to Do',
              onAdd: () => onAddThing(city),
            ),
            const SizedBox(height: 6),
            if (city.thingsToDo.isEmpty)
              const WishlistManualEditMutedHint(text: 'No activity items for this city.'),
            ...city.thingsToDo.asMap().entries.map((thingEntry) {
              final thingIndex = thingEntry.key;
              final thing = thingEntry.value;
              return ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(thing.value),
                trailing: Wrap(
                  spacing: 2,
                  children: <Widget>[
                    IconButton(
                      tooltip: 'Move up',
                      onPressed: thingIndex == 0
                          ? null
                          : () => onMoveThing(city, thingIndex, thingIndex - 1),
                      icon: const Icon(Icons.keyboard_arrow_up),
                    ),
                    IconButton(
                      tooltip: 'Move down',
                      onPressed: thingIndex == city.thingsToDo.length - 1
                          ? null
                          : () => onMoveThing(city, thingIndex, thingIndex + 1),
                      icon: const Icon(Icons.keyboard_arrow_down),
                    ),
                    IconButton(
                      tooltip: 'Edit',
                      onPressed: () => onEditThing(city, thingIndex),
                      icon: const Icon(Icons.edit_outlined),
                    ),
                    IconButton(
                      tooltip: 'Delete',
                      onPressed: () => onDeleteThing(city, thingIndex),
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
