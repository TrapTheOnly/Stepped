import 'package:flutter/material.dart';

import '../../../widgets/frosted_squircle.dart';
import '../wishlist_plan_manual_edit_models.dart';
import 'wishlist_editor_shell.dart';
import 'wishlist_manual_edit_common_widgets.dart';

class WishlistManualEditCitiesSection extends StatelessWidget {
  const WishlistManualEditCitiesSection({
    super.key,
    required this.cities,
    required this.onAddCity,
    required this.onOpenCity,
    required this.onMoveCity,
    required this.onDeleteCity,
  });

  final List<EditableCity> cities;
  final VoidCallback onAddCity;
  final ValueChanged<int> onOpenCity;
  final void Function(int from, int to) onMoveCity;
  final ValueChanged<int> onDeleteCity;

  @override
  Widget build(BuildContext context) {
    return WishlistEditorSectionCard(
      title: 'Route details',
      subtitle:
          'Keep this screen focused on the route shape. Open a city to edit its timeline, notes, and activities on its own page.',
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
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _CitySummaryCard(
                  city: city,
                  canMoveUp: index > 0,
                  canMoveDown: index < cities.length - 1,
                  onOpen: () => onOpenCity(index),
                  onMoveUp:
                      index == 0 ? null : () => onMoveCity(index, index - 1),
                  onMoveDown: index == cities.length - 1
                      ? null
                      : () => onMoveCity(index, index + 1),
                  onDelete: () => onDeleteCity(index),
                ),
              );
            }),
        ],
      ),
    );
  }
}

class _CitySummaryCard extends StatelessWidget {
  const _CitySummaryCard({
    required this.city,
    required this.canMoveUp,
    required this.canMoveDown,
    required this.onOpen,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onDelete,
  });

  final EditableCity city;
  final bool canMoveUp;
  final bool canMoveDown;
  final VoidCallback onOpen;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return FrostedSquircle(
      radius: 28,
      blurSigma: 16,
      color: scheme.surfaceContainerLowest.withValues(alpha: 0.86),
      borderColor: scheme.outlineVariant.withValues(alpha: 0.12),
      shadowColor: scheme.primary.withValues(alpha: 0.06),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      city.city.trim().isEmpty ? 'Untitled city' : city.city,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      city.reason.trim().isEmpty
                          ? 'Add a short reason for this stop.'
                          : city.reason.trim(),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: scheme.onSurfaceVariant,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              _CityInfoChip(label: '${city.days} days'),
              _CityInfoChip(label: '${city.timeline.length} timeline stops'),
              _CityInfoChip(label: '${city.thingsToDo.length} things to do'),
              if (city.isExtra) const _CityInfoChip(label: 'Extra city'),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              FilledButton.icon(
                onPressed: onOpen,
                icon: const Icon(Icons.edit_note_rounded),
                label: const Text('Edit city'),
              ),
              _CityActionButton(
                label: 'Up',
                icon: Icons.keyboard_arrow_up_rounded,
                onTap: onMoveUp,
                enabled: canMoveUp,
              ),
              _CityActionButton(
                label: 'Down',
                icon: Icons.keyboard_arrow_down_rounded,
                onTap: onMoveDown,
                enabled: canMoveDown,
              ),
              _CityActionButton(
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

class _CityInfoChip extends StatelessWidget {
  const _CityInfoChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: ShapeDecoration(
        color: scheme.surface.withValues(alpha: 0.72),
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

class _CityActionButton extends StatelessWidget {
  const _CityActionButton({
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
