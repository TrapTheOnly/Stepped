import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../widgets/country_flag.dart';

class AddTripDestinationPreview extends StatelessWidget {
  const AddTripDestinationPreview({
    super.key,
    required this.countryCode,
    required this.countryName,
  });

  final String? countryCode;
  final String? countryName;

  @override
  Widget build(BuildContext context) {
    final width = math.min(MediaQuery.sizeOf(context).width * 0.5, 220.0);
    final height = width * 0.75;
    final scheme = Theme.of(context).colorScheme;

    return Column(
      children: <Widget>[
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          child: countryCode == null
              ? Container(
                  key: const ValueKey<String>('globe'),
                  width: width,
                  height: height,
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(
                    Icons.public,
                    size: width * 0.42,
                    color: scheme.onSurfaceVariant,
                  ),
                )
              : CountryFlag(
                  key: ValueKey<String>(countryCode!),
                  iso2: countryCode!,
                  width: width,
                  height: height,
                  borderRadius: 20,
                ),
        ),
        const SizedBox(height: 10),
        Text(
          countryName ?? 'Choose a destination',
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ],
    );
  }
}
