import 'package:flutter/material.dart';

import '../../data/db/app_db.dart';
import '../map/globe/globe_country_data.dart';
import 'add_trip_form_types.dart';

InputDecorationTheme roundedTripInputDecorationTheme(BuildContext context) {
  final scheme = Theme.of(context).colorScheme;
  final border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(18),
    borderSide: BorderSide(color: scheme.outlineVariant),
  );
  return InputDecorationTheme(
    filled: true,
    fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
    border: border,
    enabledBorder: border,
    focusedBorder: border.copyWith(
      borderSide: BorderSide(color: scheme.primary, width: 1.4),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
  );
}

List<TripCountryOption> buildTripCountryOptions(
  List<GlobeCountryShape> countries, {
  TripRecord? existingTrip,
  String? selectedCountryCode,
  String? selectedCountryName,
}) {
  final byCode = <String, TripCountryOption>{
    for (final country in countries)
      country.iso2.toUpperCase(): TripCountryOption(
        code: country.iso2.toUpperCase(),
        name: country.name,
      ),
    for (final country in tripMicrostatesSearchOnly) country.code: country,
  };

  if (existingTrip != null) {
    final code = existingTrip.countryCode.toUpperCase();
    byCode.putIfAbsent(
      code,
      () => TripCountryOption(
        code: code,
        name: existingTrip.countryName,
      ),
    );
  }

  if (selectedCountryCode != null && selectedCountryName != null) {
    final code = selectedCountryCode.toUpperCase();
    byCode.putIfAbsent(
      code,
      () => TripCountryOption(
        code: code,
        name: selectedCountryName,
      ),
    );
  }

  final options = byCode.values.toList(growable: false)
    ..sort((left, right) => left.name.compareTo(right.name));
  return options;
}
