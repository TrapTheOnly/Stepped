import 'package:flutter/material.dart';

import '../../../widgets/country_flag.dart';
import '../../../widgets/frosted_squircle.dart';
import '../search_models.dart';

class SearchResultCard extends StatelessWidget {
  const SearchResultCard({
    super.key,
    required this.entry,
    required this.onTap,
  });

  final CountrySearchEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        customBorder: squircleShape(28),
        child: FrostedSquircle(
          radius: 28,
          blurSigma: 12,
          color: colorScheme.surface.withValues(alpha: 0.62),
          borderColor: colorScheme.outlineVariant.withValues(alpha: 0.10),
          shadowColor: colorScheme.primary.withValues(alpha: 0.06),
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Row(
            children: <Widget>[
              CountryFlag(
                iso2: entry.iso2,
                width: 32,
                height: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      entry.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      '${entry.iso2} · ${entry.continent ?? 'Unknown continent'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                    ),
                    if (entry.visited || entry.tripCount > 0) ...<Widget>[
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: <Widget>[
                          if (entry.visited)
                            const _MetaChip(
                              label: 'Visited',
                              icon: Icons.check_circle_rounded,
                            ),
                          if (entry.tripCount > 0)
                            _MetaChip(
                              label:
                                  '${entry.tripCount} trip${entry.tripCount == 1 ? '' : 's'}',
                              icon: Icons.flight_takeoff_rounded,
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({
    required this.label,
    required this.icon,
  });

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 14, color: colorScheme.primary),
            const SizedBox(width: 6),
            Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
