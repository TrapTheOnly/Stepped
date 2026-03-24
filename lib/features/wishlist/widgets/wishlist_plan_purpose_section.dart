import 'package:flutter/material.dart';

import 'wishlist_editor_shell.dart';

class WishlistPlanPurposeSection extends StatelessWidget {
  const WishlistPlanPurposeSection({
    super.key,
    required this.controller,
    required this.currentLength,
    required this.maxLength,
    required this.onChanged,
  });

  final TextEditingController controller;
  final int currentLength;
  final int maxLength;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return WishlistEditorSectionCard(
      title: 'Trip purpose',
      subtitle:
          'Tell AI what you want from this trip in a short note so it can shape the cities, timing, and cover image around that intent.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          TextField(
            controller: controller,
            minLines: 3,
            maxLines: 5,
            maxLength: maxLength,
            decoration: const InputDecoration(
              labelText: 'What are you hoping to do or see?',
              hintText:
                  'Chase the Northern Lights, snorkel warm reefs, wander ancient markets...',
              alignLabelWithHint: true,
              prefixIcon: Icon(Icons.lightbulb_outline_rounded),
            ),
            onChanged: onChanged,
          ),
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              Icon(
                Icons.bolt_outlined,
                size: 16,
                color: scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Keep it focused. AI uses this note to bias the route, activity suggestions, and the wishlist cover image.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '$currentLength/$maxLength',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
