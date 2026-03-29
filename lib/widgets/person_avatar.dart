import 'dart:io';

import 'package:flutter/material.dart';

import '../features/social/social_asset_urls.dart';

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
    final diameter = radius * 2;

    return SizedBox(
      width: diameter,
      height: diameter,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          DecoratedBox(
            decoration: BoxDecoration(
              color: backgroundColor ?? colorScheme.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: _InitialsLabel(
                initials: initials,
                color: foregroundColor ?? colorScheme.onPrimaryContainer,
              ),
            ),
          ),
          if (imageProvider != null)
            ClipOval(
              child: Image(
                image: imageProvider,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
        ],
      ),
    );
  }

  ImageProvider<Object>? _imageProviderFor(String? rawPhotoUrl) {
    final normalizedPhotoUrl = normalizeSocialAssetUrl(rawPhotoUrl);
    if (normalizedPhotoUrl == null || normalizedPhotoUrl.isEmpty) {
      return null;
    }

    final parsed = Uri.tryParse(normalizedPhotoUrl);
    final scheme = parsed?.scheme.toLowerCase();
    if (scheme == 'http' || scheme == 'https') {
      return NetworkImage(normalizedPhotoUrl);
    }
    if (scheme == 'file') {
      final file = File.fromUri(parsed!);
      return file.existsSync() ? FileImage(file) : null;
    }

    final file = File(normalizedPhotoUrl);
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

class _InitialsLabel extends StatelessWidget {
  const _InitialsLabel({
    required this.initials,
    required this.color,
  });

  final String initials;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text(
      initials,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: color,
          ),
    );
  }
}
