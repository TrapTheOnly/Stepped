import 'package:flutter/material.dart';

import 'wishlist_plan_manual_edit_models.dart';

Future<EditableTimeWindow?> showWishlistManualTimeWindowDialog(
  BuildContext context, {
  EditableTimeWindow? existing,
  required int Function() allocateId,
}) async {
  final labelController = TextEditingController(text: existing?.label ?? '');
  final monthsController = TextEditingController(text: existing?.months ?? '');
  final reasonController = TextEditingController(text: existing?.reason ?? '');

  final result = await showDialog<EditableTimeWindow>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: Text(existing == null ? 'Add Time Window' : 'Edit Time Window'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TextField(
                controller: labelController,
                decoration: const InputDecoration(
                  labelText: 'Label',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: monthsController,
                decoration: const InputDecoration(
                  labelText: 'Months',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: reasonController,
                minLines: 1,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Reason',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final label = labelController.text.trim();
              final months = monthsController.text.trim();
              final reason = reasonController.text.trim();
              if (label.isEmpty || months.isEmpty || reason.isEmpty) {
                return;
              }
              Navigator.of(dialogContext).pop(
                EditableTimeWindow(
                  id: existing?.id ?? allocateId(),
                  label: label,
                  months: months,
                  reason: reason,
                ),
              );
            },
            child: const Text('Save'),
          ),
        ],
      );
    },
  );

  labelController.dispose();
  monthsController.dispose();
  reasonController.dispose();
  return result;
}

Future<EditableCity?> showWishlistManualCityDialog(
  BuildContext context, {
  required int Function() allocateId,
}) async {
  final cityController = TextEditingController();
  final daysController = TextEditingController(text: '2');
  final reasonController = TextEditingController();

  final result = await showDialog<EditableCity>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: const Text('Add City'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TextField(
                controller: cityController,
                decoration: const InputDecoration(
                  labelText: 'City',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: daysController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Days',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: reasonController,
                decoration: const InputDecoration(
                  labelText: 'Reason',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final city = cityController.text.trim();
              final days = int.tryParse(daysController.text.trim());
              final reason = reasonController.text.trim();
              if (city.isEmpty || days == null || days <= 0 || reason.isEmpty) {
                return;
              }
              Navigator.of(dialogContext).pop(
                EditableCity(
                  id: allocateId(),
                  originalCityKey: null,
                  originalImageQuery: '$city skyline',
                  city: city,
                  days: days,
                  reason: reason,
                  isExtra: false,
                  overview: '',
                  imageQuery: '$city skyline',
                  timeline: <EditableTimeline>[],
                  thingsToDo: <EditableThing>[],
                ),
              );
            },
            child: const Text('Add'),
          ),
        ],
      );
    },
  );

  cityController.dispose();
  daysController.dispose();
  reasonController.dispose();
  return result;
}

Future<EditableTimeline?> showWishlistManualTimelineDialog(
  BuildContext context, {
  EditableTimeline? existing,
  required int Function() allocateId,
}) async {
  final slotController = TextEditingController(text: existing?.slot ?? '');
  final placeController = TextEditingController(text: existing?.place ?? '');
  final noteController = TextEditingController(text: existing?.note ?? '');

  final result = await showDialog<EditableTimeline>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: Text(existing == null ? 'Add Timeline Step' : 'Edit Timeline Step'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TextField(
                controller: slotController,
                decoration: const InputDecoration(
                  labelText: 'Day/slot',
                  hintText: 'Day 1 AM',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: placeController,
                decoration: const InputDecoration(
                  labelText: 'Place',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: noteController,
                minLines: 1,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Note',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final slot = slotController.text.trim();
              final place = placeController.text.trim();
              final note = noteController.text.trim();
              if (slot.isEmpty || place.isEmpty || note.isEmpty) {
                return;
              }
              Navigator.of(dialogContext).pop(
                EditableTimeline(
                  id: existing?.id ?? allocateId(),
                  slot: slot,
                  place: place,
                  note: note,
                ),
              );
            },
            child: const Text('Save'),
          ),
        ],
      );
    },
  );

  slotController.dispose();
  placeController.dispose();
  noteController.dispose();
  return result;
}

Future<EditableThing?> showWishlistManualThingDialog(
  BuildContext context, {
  EditableThing? existing,
  required int Function() allocateId,
}) async {
  final valueController = TextEditingController(text: existing?.value ?? '');

  final result = await showDialog<EditableThing>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: Text(existing == null ? 'Add Activity' : 'Edit Activity'),
        content: TextField(
          controller: valueController,
          decoration: const InputDecoration(
            labelText: 'Activity',
            border: OutlineInputBorder(),
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final value = valueController.text.trim();
              if (value.isEmpty) {
                return;
              }
              Navigator.of(dialogContext).pop(
                EditableThing(
                  id: existing?.id ?? allocateId(),
                  value: value,
                ),
              );
            },
            child: const Text('Save'),
          ),
        ],
      );
    },
  );

  valueController.dispose();
  return result;
}
