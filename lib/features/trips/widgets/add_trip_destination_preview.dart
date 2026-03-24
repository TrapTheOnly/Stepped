import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AddTripDestinationPreview extends StatelessWidget {
  const AddTripDestinationPreview({
    super.key,
    required this.countryCode,
    required this.countryName,
    required this.coverImageUri,
    required this.startDate,
    required this.endDate,
  });

  final String? countryCode;
  final String? countryName;
  final String? coverImageUri;
  final DateTime? startDate;
  final DateTime? endDate;

  @override
  Widget build(BuildContext context) {
    final width = math.min(MediaQuery.sizeOf(context).width, 520.0);
    final height = math.min(width * 0.72, 286.0);

    return ClipRRect(
      borderRadius: BorderRadius.circular(32),
      child: SizedBox(
        width: width,
        height: height,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            _PreviewArtwork(
              coverImageUri: coverImageUri,
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[
                    Colors.black.withValues(alpha: 0.08),
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.64),
                  ],
                ),
              ),
            ),
            Positioned(
              left: 20,
              right: 20,
              bottom: 20,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    countryName ?? 'Choose a destination',
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                          color: Colors.white,
                          fontSize: 34,
                          height: 0.98,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _buildJourneyLabel(),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.86),
                          fontWeight: FontWeight.w600,
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

  String _buildJourneyLabel() {
    if (startDate != null && endDate != null) {
      final formatter = DateFormat('MMM d');
      final endFormatter = DateFormat('MMM d, y');
      final startLabel = startDate!.year == endDate!.year
          ? formatter.format(startDate!)
          : endFormatter.format(startDate!);
      return '$startLabel - ${endFormatter.format(endDate!)}';
    }

    return 'A quiet place for the next chapter of your travels';
  }
}

class _PreviewArtwork extends StatelessWidget {
  const _PreviewArtwork({
    required this.coverImageUri,
  });

  final String? coverImageUri;

  @override
  Widget build(BuildContext context) {
    final normalized = coverImageUri?.trim() ?? '';
    if (normalized.isNotEmpty) {
      if (normalized.startsWith('http://') ||
          normalized.startsWith('https://')) {
        return Image.network(
          normalized,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const _FallbackArtwork(),
        );
      }

      final localPath = normalized.startsWith('file://')
          ? normalized.replaceFirst('file://', '')
          : normalized;
      final file = File(localPath);
      if (file.existsSync()) {
        return Image.file(file, fit: BoxFit.cover);
      }
    }

    return const _FallbackArtwork();
  }
}

class _FallbackArtwork extends StatelessWidget {
  const _FallbackArtwork();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            scheme.surfaceContainerHigh.withValues(alpha: 0.92),
            scheme.surfaceContainer.withValues(alpha: 0.86),
            scheme.surfaceContainerLow.withValues(alpha: 0.94),
          ],
        ),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0.55, -0.15),
            radius: 1.2,
            colors: <Color>[
              scheme.primary.withValues(alpha: 0.16),
              Colors.transparent,
            ],
          ),
        ),
      ),
    );
  }
}
