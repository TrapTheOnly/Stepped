import 'dart:io';

import 'package:flutter/material.dart';

class AddTripCoverImagePreview extends StatelessWidget {
  const AddTripCoverImagePreview({super.key, required this.uri});

  final String uri;

  @override
  Widget build(BuildContext context) {
    final normalized = uri.trim();
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
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        height: 140,
        width: double.infinity,
        child: ColoredBox(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: content,
        ),
      ),
    );
  }
}

class _CoverPlaceholder extends StatelessWidget {
  const _CoverPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Icon(
        Icons.image_not_supported_outlined,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}
