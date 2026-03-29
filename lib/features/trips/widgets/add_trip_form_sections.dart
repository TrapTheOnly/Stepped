import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../widgets/frosted_squircle.dart';
import '../add_trip_form_types.dart';
import '../trip_city_models.dart';
import '../../wishlist/gemini_trip_planner.dart';
import 'add_trip_country_autocomplete_field.dart';
import 'add_trip_cover_image_preview.dart';
import 'add_trip_date_field.dart';

class AddTripDestinationSection extends StatelessWidget {
  const AddTripDestinationSection({
    super.key,
    required this.countryFieldKey,
    required this.countryFocusNode,
    required this.countrySearchController,
    required this.countries,
    required this.countryValidationError,
    required this.onTyped,
    required this.onSelected,
  });

  final GlobalKey countryFieldKey;
  final FocusNode countryFocusNode;
  final TextEditingController countrySearchController;
  final List<TripCountryOption> countries;
  final String? countryValidationError;
  final ValueChanged<String> onTyped;
  final ValueChanged<TripCountryOption> onSelected;

  @override
  Widget build(BuildContext context) {
    return _EditorSectionShell(
      title: 'Destination',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          AddTripCountryAutocompleteField(
            fieldKey: countryFieldKey,
            focusNode: countryFocusNode,
            controller: countrySearchController,
            options: countries,
            onTyped: onTyped,
            onSelected: onSelected,
          ),
          if (countryValidationError != null)
            Padding(
              padding: const EdgeInsets.only(top: 8, left: 4),
              child: Text(
                countryValidationError!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class AddTripTravelDetailsSection extends StatelessWidget {
  const AddTripTravelDetailsSection({
    super.key,
    required this.startDate,
    required this.endDate,
    required this.cityInputController,
    required this.cities,
    required this.cityValidationError,
    required this.suggestedCities,
    this.inheritedSourceTitle,
    this.inheritance,
    required this.onPickDateRange,
    required this.onAddTypedCities,
    required this.onAddSuggestedCity,
    required this.onOpenCity,
    required this.onRemoveCity,
  });

  final DateTime? startDate;
  final DateTime? endDate;
  final TextEditingController cityInputController;
  final List<TripCityEntry> cities;
  final String? cityValidationError;
  final List<String> suggestedCities;
  final String? inheritedSourceTitle;
  final TripWishlistInheritance? inheritance;
  final VoidCallback onPickDateRange;
  final VoidCallback onAddTypedCities;
  final ValueChanged<String> onAddSuggestedCity;
  final ValueChanged<TripCityEntry> onOpenCity;
  final ValueChanged<TripCityEntry> onRemoveCity;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return _EditorSectionShell(
      title: 'Travel Details',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          AddTripDateField(
            label: 'Travel dates',
            startDate: startDate,
            endDate: endDate,
            onTap: onPickDateRange,
          ),
          if (startDate == null || endDate == null)
            Padding(
              padding: const EdgeInsets.only(top: 8, left: 4),
              child: Text(
                'Start and end dates are required.',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ),
          if (inheritedSourceTitle != null) ...<Widget>[
            const SizedBox(height: 16),
            DecoratedBox(
              decoration: ShapeDecoration(
                color: colorScheme.secondaryContainer.withValues(alpha: 0.5),
                shape: squircleShape(20),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Icon(
                      Icons.route_rounded,
                      color: colorScheme.onSecondaryContainer,
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Linked to wishlist itinerary: $inheritedSourceTitle',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSecondaryContainer,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: TextFormField(
                  controller: cityInputController,
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(
                    labelText: 'Add city',
                    hintText: 'Type one city or paste a comma-separated list',
                  ),
                  onFieldSubmitted: (_) => onAddTypedCities(),
                ),
              ),
              const SizedBox(width: 10),
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: FilledButton(
                  onPressed: onAddTypedCities,
                  child: const Text('Add'),
                ),
              ),
            ],
          ),
          if (suggestedCities.isNotEmpty) ...<Widget>[
            const SizedBox(height: 14),
            Text(
              'Suggested from itinerary',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: suggestedCities
                  .map(
                    (city) => _TripSuggestionChip(
                      label: city,
                      onTap: () => onAddSuggestedCity(city),
                    ),
                  )
                  .toList(growable: false),
            ),
          ],
          if (cityValidationError != null)
            Padding(
              padding: const EdgeInsets.only(top: 10, left: 4),
              child: Text(
                cityValidationError!,
                style: TextStyle(color: colorScheme.error),
              ),
            ),
          const SizedBox(height: 18),
          Text(
            'Route details',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 16),
          if (cities.isEmpty)
            Text(
              'Add at least one city to shape the trip.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
            )
          else
            Column(
              children: cities
                  .map(
                    (city) => Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: TripCityRouteCard(
                        city: city,
                        inheritedPlan: inheritance?.cityPlanFor(city.name),
                        inheritedDetail: inheritance?.cityDetailFor(city.name),
                        onOpen: () => onOpenCity(city),
                        onRemove: () => onRemoveCity(city),
                      ),
                    ),
                  )
                  .toList(growable: false),
            ),
        ],
      ),
    );
  }
}

class AddTripMediaNotesSection extends StatelessWidget {
  const AddTripMediaNotesSection({
    super.key,
    required this.coverImageController,
    required this.notesController,
    required this.onPickCoverImageFromDevice,
    required this.onClearCoverImage,
  });

  final TextEditingController coverImageController;
  final TextEditingController notesController;
  final VoidCallback onPickCoverImageFromDevice;
  final VoidCallback onClearCoverImage;

  @override
  Widget build(BuildContext context) {
    return _EditorSectionShell(
      title: 'Media & Notes',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Cover image',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onPickCoverImageFromDevice,
                  icon: const Icon(Icons.upload_file_rounded),
                  label: const Text('Upload image'),
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: coverImageController.text.trim().isEmpty
                    ? null
                    : onClearCoverImage,
                child: const Text('Clear'),
              ),
            ],
          ),
          if (coverImageController.text.trim().isNotEmpty) ...<Widget>[
            const SizedBox(height: 12),
            AddTripCoverImagePreview(uri: coverImageController.text.trim()),
          ],
          const SizedBox(height: 12),
          TextFormField(
            controller: notesController,
            minLines: 4,
            maxLines: 6,
            decoration: const InputDecoration(
              labelText: 'Notes',
              hintText:
                  'A quiet memory, a hotel tip, a favorite neighborhood...',
            ),
          ),
        ],
      ),
    );
  }
}

class _EditorSectionShell extends StatelessWidget {
  const _EditorSectionShell({
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return FrostedSquircle(
      radius: 30,
      blurSigma: 16,
      color: colorScheme.surface.withValues(alpha: 0.72),
      borderColor: colorScheme.primaryContainer.withValues(alpha: 0.14),
      shadowColor: colorScheme.primary.withValues(alpha: 0.08),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _TripSuggestionChip extends StatelessWidget {
  const _TripSuggestionChip({
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Ink(
          decoration: ShapeDecoration(
            color: colorScheme.secondaryContainer.withValues(alpha: 0.54),
            shape: const StadiumBorder(),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSecondaryContainer,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ),
      ),
    );
  }
}

class TripCityRouteCard extends StatelessWidget {
  const TripCityRouteCard({
    super.key,
    required this.city,
    required this.inheritedPlan,
    required this.inheritedDetail,
    required this.onOpen,
    this.onRemove,
    this.showRemoveAction = true,
    this.showOpenGuideChip = false,
    this.fallbackRouteReason,
  });

  final TripCityEntry city;
  final GeminiCityPlan? inheritedPlan;
  final GeminiCityDetail? inheritedDetail;
  final VoidCallback onOpen;
  final VoidCallback? onRemove;
  final bool showRemoveAction;
  final bool showOpenGuideChip;
  final String? fallbackRouteReason;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final inheritedPlan = this.inheritedPlan;
    final inheritedDetail = this.inheritedDetail;
    final manualOverview = (city.itineraryOverview ?? city.notes ?? '').trim();
    final inheritedOverview =
        (inheritedDetail?.overview ?? inheritedPlan?.reason ?? '').trim();
    final overview =
        manualOverview.isNotEmpty ? manualOverview : inheritedOverview;
    final routeReason =
        (inheritedPlan?.reason ?? overview).trim().isNotEmpty
            ? (inheritedPlan?.reason ?? overview).trim()
            : (fallbackRouteReason?.trim() ?? '');
    final stopCount = city.itineraryStops.isNotEmpty
        ? city.itineraryStops.length
        : (inheritedDetail?.timeline.length ?? 0);
    final ideaCount = city.suggestedPlaces.isNotEmpty
        ? city.suggestedPlaces.length
        : (inheritedDetail?.thingsToDo.length ?? 0);
    final dayCount = inheritedPlan?.days ?? _deriveManualDayCount(city);
    final isExtra = inheritedPlan?.isExtra ?? false;
    final hasManualGuide = tripCityHasSavedItinerary(city);

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: scheme.primary.withValues(alpha: 0.08),
            blurRadius: 26,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: Material(
          color: scheme.surfaceContainerLowest.withValues(alpha: 0.88),
          child: InkWell(
            onTap: onOpen,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                SizedBox(
                  height: 228,
                  child: Stack(
                    fit: StackFit.expand,
                    children: <Widget>[
                      _TripCityCardArtwork(
                        city: city,
                        inheritedDetail: inheritedDetail,
                      ),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: <Color>[
                              Colors.black.withValues(alpha: 0.08),
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.72),
                            ],
                            stops: const <double>[0, 0.38, 1],
                          ),
                        ),
                      ),
                      Positioned(
                        top: 16,
                        left: 16,
                        right: 16,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Expanded(
                              child: Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: <Widget>[
                                  if (dayCount != null)
                                    _TripRouteMetaChip(
                                      label:
                                          '$dayCount ${dayCount == 1 ? 'day' : 'days'}',
                                      icon: Icons.schedule_rounded,
                                      emphasized: true,
                                    ),
                                  if (isExtra)
                                    const _TripRouteMetaChip(
                                      label: 'Extra city',
                                      icon: Icons.add_location_alt_outlined,
                                      emphasized: true,
                                    )
                                  else if (hasManualGuide &&
                                      inheritedPlan == null)
                                    const _TripRouteMetaChip(
                                      label: 'Custom city',
                                      icon: Icons.edit_location_alt_outlined,
                                      emphasized: true,
                                    ),
                                ],
                              ),
                            ),
                            if (showRemoveAction) ...<Widget>[
                              const SizedBox(width: 12),
                              DecoratedBox(
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.24),
                                  shape: BoxShape.circle,
                                ),
                                child: IconButton(
                                  tooltip: 'Remove city',
                                  onPressed: onRemove,
                                  icon: const Icon(
                                    Icons.close_rounded,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      Positioned(
                        left: 18,
                        right: 18,
                        bottom: 18,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: <Widget>[
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  Text(
                                    city.name,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context)
                                        .textTheme
                                        .displaySmall
                                        ?.copyWith(
                                          color: Colors.white,
                                          fontSize: 34,
                                          height: 0.96,
                                          fontWeight: FontWeight.w700,
                                        ),
                                  ),
                                  if (routeReason.isNotEmpty) ...<Widget>[
                                    const SizedBox(height: 6),
                                    Text(
                                      routeReason,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                            color: Colors.white
                                                .withValues(alpha: 0.86),
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            DecoratedBox(
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.16),
                                shape: BoxShape.circle,
                              ),
                              child: const Padding(
                                padding: EdgeInsets.all(10),
                                child: Icon(
                                  Icons.arrow_outward_rounded,
                                  color: Colors.white,
                                  size: 22,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      if (overview.isNotEmpty) ...<Widget>[
                        Text(
                          overview,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                  ),
                        ),
                        const SizedBox(height: 14),
                      ],
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: <Widget>[
                          if (stopCount > 0)
                            _TripRouteMetaChip(
                              label: '$stopCount stop${stopCount == 1 ? '' : 's'}',
                              icon: Icons.route_outlined,
                            ),
                          if (ideaCount > 0)
                            _TripRouteMetaChip(
                              label: '$ideaCount idea${ideaCount == 1 ? '' : 's'}',
                              icon: Icons.checklist_rounded,
                            ),
                          if (showOpenGuideChip)
                            const _TripRouteMetaChip(
                              label: 'Open city guide',
                              icon: Icons.open_in_new_rounded,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TripCityCardArtwork extends StatelessWidget {
  const _TripCityCardArtwork({
    required this.city,
    required this.inheritedDetail,
  });

  final TripCityEntry city;
  final GeminiCityDetail? inheritedDetail;

  @override
  Widget build(BuildContext context) {
    final customImage = city.imageUri?.trim();
    if (customImage != null && customImage.isNotEmpty) {
      if (customImage.startsWith('http://') || customImage.startsWith('https://')) {
        return CachedNetworkImage(
          imageUrl: customImage,
          fit: BoxFit.cover,
          errorWidget: (_, __, ___) => const _TripCityImageFallback(),
        );
      }

      final file = File(
        customImage.startsWith('file://')
            ? customImage.replaceFirst('file://', '')
            : customImage,
      );
      if (file.existsSync()) {
        return Image.file(file, fit: BoxFit.cover);
      }
    }

    final inheritedImage = inheritedDetail?.image?.imageUrl.trim();
    if (inheritedImage != null && inheritedImage.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: inheritedImage,
        fit: BoxFit.cover,
        errorWidget: (_, __, ___) => const _TripCityImageFallback(),
      );
    }

    return const _TripCityImageFallback();
  }
}

class _TripCityImageFallback extends StatelessWidget {
  const _TripCityImageFallback();

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
            scheme.surfaceContainerLow.withValues(alpha: 0.96),
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

class _TripRouteMetaChip extends StatelessWidget {
  const _TripRouteMetaChip({
    required this.label,
    this.icon,
    this.emphasized = false,
  });

  final String label;
  final IconData? icon;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: ShapeDecoration(
        color: emphasized
            ? scheme.primaryContainer.withValues(alpha: 0.36)
            : scheme.surface.withValues(alpha: 0.72),
        shape: StadiumBorder(
          side: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.14),
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (icon != null) ...<Widget>[
              Icon(icon, size: 14, color: scheme.onSurfaceVariant),
              const SizedBox(width: 6),
            ],
            Flexible(
              child: Text(
                label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: scheme.onSurface,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

int? _deriveManualDayCount(TripCityEntry city) {
  if (city.itineraryStops.isEmpty) {
    return null;
  }

  final dayLabels = <String>{};
  for (final stop in city.itineraryStops) {
    final match = RegExp(r'(day\s*\d+)', caseSensitive: false)
        .firstMatch(stop.slot.trim());
    if (match != null) {
      dayLabels.add(match.group(1)!.toLowerCase());
    }
  }

  if (dayLabels.isNotEmpty) {
    return dayLabels.length;
  }

  return 1;
}
