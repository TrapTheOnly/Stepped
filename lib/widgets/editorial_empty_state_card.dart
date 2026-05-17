import 'package:flutter/material.dart';

import 'frosted_squircle.dart';

class EditorialEmptyStateCard extends StatelessWidget {
  const EditorialEmptyStateCard({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return FrostedSquircle(
      radius: 34,
      blurSigma: 20,
      color: colorScheme.surface.withValues(alpha: 0.78),
      borderColor: colorScheme.primaryContainer.withValues(alpha: 0.16),
      shadowColor: colorScheme.primary.withValues(alpha: 0.08),
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          DecoratedBox(
            decoration: ShapeDecoration(
              color: colorScheme.secondaryContainer.withValues(alpha: 0.62),
              shape: squircleShape(20),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Icon(
                icon,
                color: colorScheme.onSecondaryContainer,
                size: 22,
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }
}
