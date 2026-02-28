import 'package:flutter/material.dart';

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
    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        FilledButton.tonalIcon(
          onPressed: onAdd,
          icon: const Icon(Icons.add),
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
    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleSmall,
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
