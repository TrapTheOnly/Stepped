import 'dart:io';

import 'package:flutter/material.dart';

class PersonAvatar extends StatelessWidget {
  const PersonAvatar({
    super.key,
    required this.displayName,
    this.photoUrl,
    this.radius = 24,
    this.backgroundColor,
    this.foregroundColor,
  });

  final String displayName;
  final String? photoUrl;
  final double radius;
  final Color? backgroundColor;
  final Color? foregroundColor;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final initials = _initialsFor(displayName);
    final normalizedPhotoUrl = photoUrl?.trim();
    final imageProvider = _imageProviderFor(normalizedPhotoUrl);

    return CircleAvatar(
      radius: radius,
      backgroundColor: backgroundColor ?? colorScheme.primaryContainer,
      foregroundColor: foregroundColor ?? colorScheme.onPrimaryContainer,
      backgroundImage: imageProvider,
      child: imageProvider != null
          ? null
          : Text(
              initials,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: foregroundColor ?? colorScheme.onPrimaryContainer,
                  ),
            ),
    );
  }

  ImageProvider<Object>? _imageProviderFor(String? rawPhotoUrl) {
    if (rawPhotoUrl == null || rawPhotoUrl.isEmpty) {
      return null;
    }

    final parsed = Uri.tryParse(rawPhotoUrl);
    final scheme = parsed?.scheme.toLowerCase();
    if (scheme == 'http' || scheme == 'https') {
      return NetworkImage(rawPhotoUrl);
    }
    if (scheme == 'file') {
      final file = File.fromUri(parsed!);
      return file.existsSync() ? FileImage(file) : null;
    }

    final file = File(rawPhotoUrl);
    if (file.existsSync()) {
      return FileImage(file);
    }
    return null;
  }

  static String _initialsFor(String rawDisplayName) {
    final parts = rawDisplayName
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList(growable: false);
    if (parts.isEmpty) {
      return 'T';
    }
    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }
}
