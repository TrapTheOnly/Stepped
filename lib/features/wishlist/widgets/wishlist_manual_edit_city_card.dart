import 'package:flutter/material.dart';

import '../wishlist_plan_manual_edit_models.dart';
import 'wishlist_manual_edit_common_widgets.dart';
import '../../../widgets/frosted_squircle.dart';

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
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: FrostedSquircle(
        radius: 28,
        blurSigma: 16,
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.72),
        borderColor: Theme.of(context)
            .colorScheme
            .outlineVariant
            .withValues(alpha: 0.12),
        shadowColor:
            Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    city.city.trim().isEmpty ? 'Untitled city' : city.city,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
                IconButton(
                  tooltip: 'Move up',
                  onPressed:
                      index == 0 ? null : () => onMoveCity(index, index - 1),
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
            const SizedBox(height: 10),
            TextFormField(
              initialValue: city.city,
              decoration: const InputDecoration(
                labelText: 'City',
                prefixIcon: Icon(Icons.location_city_outlined),
              ),
              onChanged: (value) {
                city.city = value;
                onErrorClear();
              },
            ),
            const SizedBox(height: 10),
            Row(
              children: <Widget>[
                Expanded(
                  child: TextFormField(
                    initialValue: city.days.toString(),
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Days',
                      prefixIcon: Icon(Icons.schedule_outlined),
                    ),
                    onChanged: (value) {
                      city.days = int.tryParse(value.trim()) ?? city.days;
                      onErrorClear();
                    },
                  ),
                ),
                const SizedBox(width: 12),
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
            const SizedBox(height: 10),
            TextFormField(
              initialValue: city.reason,
              decoration: const InputDecoration(
                labelText: 'Why this city belongs',
                prefixIcon: Icon(Icons.push_pin_outlined),
              ),
              onChanged: (value) {
                city.reason = value;
                onErrorClear();
              },
            ),
            const SizedBox(height: 10),
            TextFormField(
              initialValue: city.overview,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'City overview',
                alignLabelWithHint: true,
                prefixIcon: Icon(Icons.menu_book_outlined),
              ),
              onChanged: (value) {
                city.overview = value;
                onErrorClear();
              },
            ),
            const SizedBox(height: 10),
            TextFormField(
              initialValue: city.imageQuery,
              decoration: const InputDecoration(
                labelText: 'Cover image query',
                prefixIcon: Icon(Icons.image_search_outlined),
              ),
              onChanged: (value) {
                city.imageQuery = value;
                onErrorClear();
              },
            ),
            if (city.image != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  'Current image: ${city.image!.source} | ${city.image!.license}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            const SizedBox(height: 14),
            WishlistManualEditSubSectionHeader(
              title: 'Timeline',
              onAdd: () => onAddTimelineStep(city),
            ),
            const SizedBox(height: 8),
            if (city.timeline.isEmpty)
              const WishlistManualEditInlineHint(
                text: 'No timeline steps for this city.',
              ),
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
                      onPressed: () =>
                          onDeleteTimelineStep(city, timelineIndex),
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 12),
            WishlistManualEditSubSectionHeader(
              title: 'Things to do',
              onAdd: () => onAddThing(city),
            ),
            const SizedBox(height: 8),
            if (city.thingsToDo.isEmpty)
              const WishlistManualEditInlineHint(
                text: 'No activity items for this city.',
              ),
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
