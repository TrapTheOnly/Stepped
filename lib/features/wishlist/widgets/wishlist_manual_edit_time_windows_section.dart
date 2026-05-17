import 'package:flutter/material.dart';

import '../wishlist_plan_manual_edit_models.dart';
import '../../../widgets/frosted_squircle.dart';
import 'wishlist_editor_shell.dart';
import 'wishlist_manual_edit_common_widgets.dart';

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
          'Shape the timing guidance that shows up in plan review without cramming every note into a tiny list tile.',
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
                padding: const EdgeInsets.only(bottom: 12),
                child: _TimeWindowCard(
                  window: window,
                  canMoveUp: index > 0,
                  canMoveDown: index < timeWindows.length - 1,
                  onMoveUp:
                      index == 0 ? null : () => onMove(index, index - 1),
                  onMoveDown: index == timeWindows.length - 1
                      ? null
                      : () => onMove(index, index + 1),
                  onEdit: () => onEdit(index),
                  onDelete: () => onDelete(index),
                ),
              );
            }),
        ],
      ),
    );
  }
}

class _TimeWindowCard extends StatelessWidget {
  const _TimeWindowCard({
    required this.window,
    required this.canMoveUp,
    required this.canMoveDown,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onEdit,
    required this.onDelete,
  });

  final EditableTimeWindow window;
  final bool canMoveUp;
  final bool canMoveDown;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return FrostedSquircle(
      radius: 26,
      blurSigma: 14,
      color: scheme.surfaceContainerLowest.withValues(alpha: 0.86),
      borderColor: scheme.outlineVariant.withValues(alpha: 0.12),
      shadowColor: scheme.primary.withValues(alpha: 0.06),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            window.label,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 8),
          _WindowChip(label: window.months),
          const SizedBox(height: 10),
          Text(
            window.reason,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              _WindowActionButton(
                label: 'Move up',
                icon: Icons.keyboard_arrow_up_rounded,
                onTap: onMoveUp,
                enabled: canMoveUp,
              ),
              _WindowActionButton(
                label: 'Move down',
                icon: Icons.keyboard_arrow_down_rounded,
                onTap: onMoveDown,
                enabled: canMoveDown,
              ),
              _WindowActionButton(
                label: 'Edit',
                icon: Icons.edit_outlined,
                onTap: onEdit,
              ),
              _WindowActionButton(
                label: 'Delete',
                icon: Icons.delete_outline,
                onTap: onDelete,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WindowChip extends StatelessWidget {
  const _WindowChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: ShapeDecoration(
        color: scheme.primaryContainer.withValues(alpha: 0.28),
        shape: StadiumBorder(
          side: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.12),
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
      ),
    );
  }
}

class _WindowActionButton extends StatelessWidget {
  const _WindowActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.enabled = true,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return TextButton.icon(
      onPressed: enabled ? onTap : null,
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        foregroundColor: scheme.onSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.12),
          ),
        ),
      ),
      icon: Icon(icon, size: 18),
      label: Text(label),
    );
  }
}
