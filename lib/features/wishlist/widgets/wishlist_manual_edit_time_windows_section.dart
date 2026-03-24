import 'package:flutter/material.dart';

import '../wishlist_plan_manual_edit_models.dart';
import 'wishlist_manual_edit_common_widgets.dart';
import 'wishlist_editor_shell.dart';

class WishlistManualEditTimeWindowsSection extends StatelessWidget {
  const WishlistManualEditTimeWindowsSection({
    super.key,
    required this.timeWindows,
    required this.onAdd,
    required this.onMove,
    required this.onEdit,
    required this.onDelete,
  });

  final List<EditableTimeWindow> timeWindows;
  final VoidCallback onAdd;
  final void Function(int from, int to) onMove;
  final ValueChanged<int> onEdit;
  final ValueChanged<int> onDelete;

  @override
  Widget build(BuildContext context) {
    return WishlistEditorSectionCard(
      title: 'Season notes',
      subtitle:
          'Define the best travel windows and why they work so the plan review page can explain when to go.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          WishlistManualEditSectionHeader(title: 'Time windows', onAdd: onAdd),
          const SizedBox(height: 12),
          if (timeWindows.isEmpty)
            const WishlistManualEditInlineHint(text: 'No time windows yet.')
          else
            ...timeWindows.asMap().entries.map((entry) {
              final index = entry.key;
              final window = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    color: Theme.of(context)
                        .colorScheme
                        .surfaceContainerLowest
                        .withValues(alpha: 0.84),
                    border: Border.all(
                      color: Theme.of(context)
                          .colorScheme
                          .outlineVariant
                          .withValues(alpha: 0.12),
                    ),
                  ),
                  child: ListTile(
                    title: Text(window.label),
                    subtitle: Text('${window.months}\n${window.reason}'),
                    isThreeLine: true,
                    trailing: Wrap(
                      spacing: 2,
                      children: <Widget>[
                        IconButton(
                          tooltip: 'Move up',
                          onPressed: index == 0
                              ? null
                              : () => onMove(index, index - 1),
                          icon: const Icon(Icons.keyboard_arrow_up),
                        ),
                        IconButton(
                          tooltip: 'Move down',
                          onPressed: index == timeWindows.length - 1
                              ? null
                              : () => onMove(index, index + 1),
                          icon: const Icon(Icons.keyboard_arrow_down),
                        ),
                        IconButton(
                          tooltip: 'Edit',
                          onPressed: () => onEdit(index),
                          icon: const Icon(Icons.edit_outlined),
                        ),
                        IconButton(
                          tooltip: 'Delete',
                          onPressed: () => onDelete(index),
                          icon: const Icon(Icons.delete_outline),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}
