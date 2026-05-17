import 'package:flutter/material.dart';

import '../features/map/widgets/map_search_dock.dart';
import 'frosted_squircle.dart';

class EditorialSearchBarRow extends StatelessWidget {
  const EditorialSearchBarRow({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onClear,
    required this.onOpenFilters,
    required this.hintText,
    this.hasActiveFilters = false,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final VoidCallback onOpenFilters;
  final String hintText;
  final bool hasActiveFilters;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: MapSearchDock(
            controller: controller,
            focusNode: focusNode,
            onChanged: onChanged,
            onClear: onClear,
            hintText: hintText,
          ),
        ),
        const SizedBox(width: 12),
        _FilterButton(
          hasActiveFilters: hasActiveFilters,
          onTap: onOpenFilters,
        ),
      ],
    );
  }
}

class EditorialActiveFilterChip extends StatelessWidget {
  const EditorialActiveFilterChip({
    super.key,
    required this.label,
    required this.onClear,
  });

  final String label;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onClear,
        customBorder: squircleShape(999),
        child: DecoratedBox(
          decoration: ShapeDecoration(
            color: colorScheme.surface.withValues(alpha: 0.72),
            shape: squircleShape(999),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(width: 6),
                Icon(
                  Icons.close_rounded,
                  size: 16,
                  color: colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class EditorialFilterSheetContainer extends StatelessWidget {
  const EditorialFilterSheetContainer({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return FrostedSquircle(
      radius: 34,
      blurSigma: 20,
      color: colorScheme.surface.withValues(alpha: 0.72),
      borderColor: colorScheme.outlineVariant.withValues(alpha: 0.16),
      shadowColor: colorScheme.primary.withValues(alpha: 0.12),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: child,
    );
  }
}

class EditorialFilterSectionTitle extends StatelessWidget {
  const EditorialFilterSectionTitle(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
    );
  }
}

class EditorialFilterChoiceChip extends StatelessWidget {
  const EditorialFilterChoiceChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final background = selected
        ? colorScheme.primary.withValues(alpha: 0.9)
        : colorScheme.surfaceContainerHighest.withValues(alpha: 0.78);
    final foreground =
        selected ? colorScheme.onPrimary : colorScheme.onSurfaceVariant;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        customBorder: squircleShape(999),
        child: DecoratedBox(
          decoration: ShapeDecoration(
            color: background,
            shape: squircleShape(999),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: foreground,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ),
      ),
    );
  }
}

class EditorialFilterActionButton extends StatelessWidget {
  const EditorialFilterActionButton({
    super.key,
    required this.label,
    required this.onTap,
    this.emphasized = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          customBorder: squircleShape(20),
          child: DecoratedBox(
            decoration: ShapeDecoration(
              color: emphasized
                  ? colorScheme.primary.withValues(alpha: 0.92)
                  : colorScheme.surfaceContainerHighest.withValues(alpha: 0.82),
              shape: squircleShape(20),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: emphasized
                          ? colorScheme.onPrimary
                          : colorScheme.onSurface,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FilterButton extends StatelessWidget {
  const _FilterButton({
    required this.hasActiveFilters,
    required this.onTap,
  });

  final bool hasActiveFilters;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        customBorder: squircleShape(24),
        child: FrostedSquircle(
          radius: 24,
          blurSigma: 16,
          color: colorScheme.surface.withValues(alpha: 0.52),
          borderColor: colorScheme.outlineVariant.withValues(alpha: 0.12),
          padding: const EdgeInsets.all(0),
          child: SizedBox(
            width: 56,
            height: 56,
            child: Stack(
              alignment: Alignment.center,
              children: <Widget>[
                Icon(
                  Icons.tune_rounded,
                  color: colorScheme.onSurfaceVariant,
                ),
                if (hasActiveFilters)
                  Positioned(
                    top: 14,
                    right: 14,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: colorScheme.primary,
                        shape: BoxShape.circle,
                      ),
                      child: const SizedBox(width: 10, height: 10),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
