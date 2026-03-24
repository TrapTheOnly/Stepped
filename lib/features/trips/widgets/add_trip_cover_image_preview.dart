import 'dart:io';

import 'package:flutter/material.dart';

class AddTripCoverImagePreview extends StatelessWidget {
  const AddTripCoverImagePreview({super.key, required this.uri});

  final String uri;

  @override
  Widget build(BuildContext context) {
    final normalized = uri.trim();
    final colorScheme = Theme.of(context).colorScheme;
    Widget content;

    if (normalized.startsWith('http://') || normalized.startsWith('https://')) {
      content = Image.network(
        normalized,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const _CoverPlaceholder(),
        loadingBuilder: (context, child, progress) {
          if (progress == null) {
            return child;
          }
          return const _CoverPlaceholder();
        },
      );
    } else {
      final localPath = normalized.startsWith('file://')
          ? normalized.replaceFirst('file://', '')
          : normalized;
      final file = File(localPath);
      content = file.existsSync()
          ? Image.file(file, fit: BoxFit.cover)
          : const _CoverPlaceholder();
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: SizedBox(
        height: 190,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            ColoredBox(
              color: colorScheme.surfaceContainerHighest,
              child: content,
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[
                    Colors.black.withValues(alpha: 0.04),
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.18),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CoverPlaceholder extends StatelessWidget {
  const _CoverPlaceholder();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            Icons.image_not_supported_outlined,
            color: colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 8),
          Text(
            'Preview unavailable',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }
}
