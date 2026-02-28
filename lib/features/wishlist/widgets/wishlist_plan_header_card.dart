import 'package:flutter/material.dart';

class WishlistPlanHeaderCard extends StatelessWidget {
  const WishlistPlanHeaderCard({super.key, required this.itemTitle});

  final String itemTitle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Row(
          children: <Widget>[
            CircleAvatar(
              radius: 23,
              backgroundColor: scheme.secondaryContainer,
              child: Icon(
                Icons.route_outlined,
                color: scheme.onSecondaryContainer,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    itemTitle,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Generate a city-level plan, duration fit, and expandable city cards.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
