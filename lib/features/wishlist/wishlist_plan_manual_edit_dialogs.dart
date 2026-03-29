import 'package:flutter/material.dart';

import 'widgets/wishlist_editor_shell.dart';
import 'wishlist_plan_manual_edit_models.dart';

Future<EditableTimeWindow?> showWishlistManualTimeWindowDialog(
  BuildContext context, {
  EditableTimeWindow? existing,
  required int Function() allocateId,
}) async {
  final labelController = TextEditingController(text: existing?.label ?? '');
  final monthsController = TextEditingController(text: existing?.months ?? '');
  final reasonController = TextEditingController(text: existing?.reason ?? '');

  final result = await _showWishlistManualDialog<EditableTimeWindow>(
    context,
    title: existing == null ? 'Add Season Note' : 'Edit Season Note',
    body: (dialogContext) => Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        TextField(
          controller: labelController,
          decoration: const InputDecoration(labelText: 'Label'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: monthsController,
          decoration: const InputDecoration(labelText: 'Months'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: reasonController,
          minLines: 2,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: 'Why this timing works',
            alignLabelWithHint: true,
          ),
        ),
      ],
    ),
    onSave: () {
      final label = labelController.text.trim();
      final months = monthsController.text.trim();
      final reason = reasonController.text.trim();
      if (label.isEmpty || months.isEmpty || reason.isEmpty) {
        return null;
      }
      return EditableTimeWindow(
        id: existing?.id ?? allocateId(),
        label: label,
        months: months,
        reason: reason,
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

  final result = await _showWishlistManualDialog<EditableCity>(
    context,
    title: 'Add City',
    body: (dialogContext) => Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        TextField(
          controller: cityController,
          decoration: const InputDecoration(labelText: 'City'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: daysController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Days'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: reasonController,
          minLines: 2,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: 'Why this stop belongs',
            alignLabelWithHint: true,
          ),
        ),
      ],
    ),
    onSave: () {
      final city = cityController.text.trim();
      final days = int.tryParse(daysController.text.trim());
      final reason = reasonController.text.trim();
      if (city.isEmpty || days == null || days <= 0 || reason.isEmpty) {
        return null;
      }
      return EditableCity(
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

  final result = await _showWishlistManualDialog<EditableTimeline>(
    context,
    title: existing == null ? 'Add Timeline Step' : 'Edit Timeline Step',
    body: (dialogContext) => Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        TextField(
          controller: slotController,
          decoration: const InputDecoration(
            labelText: 'Day / slot',
            hintText: 'Day 1 Morning',
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: placeController,
          decoration: const InputDecoration(labelText: 'Place'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: noteController,
          minLines: 2,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: 'Note',
            alignLabelWithHint: true,
          ),
        ),
      ],
    ),
    onSave: () {
      final slot = slotController.text.trim();
      final place = placeController.text.trim();
      final note = noteController.text.trim();
      if (slot.isEmpty || place.isEmpty || note.isEmpty) {
        return null;
      }
      return EditableTimeline(
        id: existing?.id ?? allocateId(),
        slot: slot,
        place: place,
        note: note,
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

  final result = await _showWishlistManualDialog<EditableThing>(
    context,
    title: existing == null ? 'Add Activity' : 'Edit Activity',
    body: (dialogContext) => TextField(
      controller: valueController,
      minLines: 2,
      maxLines: 4,
      decoration: const InputDecoration(
        labelText: 'Activity',
        alignLabelWithHint: true,
      ),
    ),
    onSave: () {
      final value = valueController.text.trim();
      if (value.isEmpty) {
        return null;
      }
      return EditableThing(
        id: existing?.id ?? allocateId(),
        value: value,
      );
    },
  );

  valueController.dispose();
  return result;
}

Future<T?> _showWishlistManualDialog<T>(
  BuildContext context, {
  required String title,
  required WidgetBuilder body,
  required T? Function() onSave,
}) {
  return showDialog<T>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.42),
    builder: (dialogContext) {
      return Theme(
        data: Theme.of(dialogContext).copyWith(
          inputDecorationTheme: wishlistEditorInputDecorationTheme(dialogContext),
        ),
        child: Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: WishlistEditorSectionCard(
            title: title,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                body(dialogContext),
                const SizedBox(height: 18),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () {
                          final result = onSave();
                          if (result == null) {
                            return;
                          }
                          Navigator.of(dialogContext).pop(result);
                        },
                        icon: const Icon(Icons.check_rounded),
                        label: const Text('Save'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
