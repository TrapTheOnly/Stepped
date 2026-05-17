import 'package:flutter/material.dart';

import 'wishlist_editor_shell.dart';

class WishlistManualEditSectionHeader extends StatelessWidget {
  const WishlistManualEditSectionHeader({
    super.key,
    required this.title,
    required this.onAdd,
  });

  final String title;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 120, maxWidth: 220),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
        FilledButton.icon(
          onPressed: onAdd,
          icon: const Icon(Icons.add_rounded),
          label: const Text('Add'),
        ),
      ],
    );
  }
}

class WishlistManualEditSubSectionHeader extends StatelessWidget {
  const WishlistManualEditSubSectionHeader({
    super.key,
    required this.title,
    required this.onAdd,
  });

  final String title;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 120, maxWidth: 220),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
        TextButton.icon(
          onPressed: onAdd,
          icon: const Icon(Icons.add),
          label: const Text('Add'),
        ),
      ],
    );
  }
}

class WishlistManualEditMutedHint extends StatelessWidget {
  const WishlistManualEditMutedHint({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return WishlistEditorSectionCard(
      title: 'Nothing here yet',
      subtitle: text,
      child: const SizedBox.shrink(),
    );
  }
}

class WishlistManualEditInlineHint extends StatelessWidget {
  const WishlistManualEditInlineHint({
    super.key,
    required this.text,
  });

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
      ),
    );
  }
}
