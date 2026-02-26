import 'package:flutter/material.dart';

const _countryCodePattern = r'^[A-Za-z]{2}$';

String countryFlagAssetPath(String iso2) {
  final normalized = iso2.trim().toLowerCase();
  if (!RegExp(_countryCodePattern).hasMatch(normalized)) {
    return '';
  }
  return 'assets/flags/$normalized.png';
}

class CountryFlag extends StatelessWidget {
  const CountryFlag({
    super.key,
    required this.iso2,
    this.width = 24,
    this.height = 18,
    this.borderRadius = 4,
  });

  final String iso2;
  final double width;
  final double height;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final assetPath = countryFlagAssetPath(iso2);

    final borderColor = Theme.of(context).colorScheme.outlineVariant;
    return SizedBox(
      width: width,
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(borderRadius),
          border: Border.all(color: borderColor),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(borderRadius),
          child: assetPath.isEmpty
              ? _fallback(context)
              : Image.asset(
                  assetPath,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _fallback(context),
                ),
        ),
      ),
    );
  }

  Widget _fallback(BuildContext context) {
    return ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Center(
        child: Text(
          iso2.trim().toUpperCase(),
          maxLines: 1,
          overflow: TextOverflow.clip,
          style: Theme.of(context).textTheme.labelSmall,
        ),
      ),
    );
  }
}
