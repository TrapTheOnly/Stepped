import 'package:flutter/material.dart';

class WishlistPlanCityPreferencesSection extends StatelessWidget {
  const WishlistPlanCityPreferencesSection({
    super.key,
    required this.noCities,
    required this.allowAdditionalCities,
    required this.citiesController,
    required this.hasPreferredCityInput,
    required this.cityValidationText,
    required this.preferredCityCount,
    required this.maxCitiesPerRequest,
    required this.onNoCitiesChanged,
    required this.onCitiesChanged,
    required this.onAllowAdditionalCitiesChanged,
  });

  final bool noCities;
  final bool allowAdditionalCities;
  final TextEditingController citiesController;
  final bool hasPreferredCityInput;
  final String? cityValidationText;
  final int preferredCityCount;
  final int maxCitiesPerRequest;
  final ValueChanged<bool> onNoCitiesChanged;
  final ValueChanged<String> onCitiesChanged;
  final ValueChanged<bool> onAllowAdditionalCitiesChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              '3) Cities in your mind',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 10),
            SwitchListTile(
              value: noCities,
              title: const Text("I don't have cities yet"),
              contentPadding: EdgeInsets.zero,
              onChanged: onNoCitiesChanged,
            ),
            if (!noCities)
              TextField(
                controller: citiesController,
                decoration: const InputDecoration(
                  labelText: 'Preferred cities',
                  hintText: 'Madrid, Barcelona',
                  border: OutlineInputBorder(),
                ),
                onChanged: onCitiesChanged,
              ),
            if (!noCities) ...<Widget>[
              const SizedBox(height: 8),
              Row(
                children: <Widget>[
                  Icon(
                    Icons.location_city_outlined,
                    size: 16,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '$preferredCityCount / $maxCitiesPerRequest cities',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: preferredCityCount > maxCitiesPerRequest
                              ? Theme.of(context).colorScheme.error
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ],
            if (cityValidationText != null) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                cityValidationText!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.error,
                    ),
              ),
            ],
            if (hasPreferredCityInput) ...<Widget>[
              const SizedBox(height: 8),
              SwitchListTile(
                value: allowAdditionalCities,
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'Allow adding nearby cities when time allows',
                ),
                subtitle: const Text(
                  'AI may add 1-2 cities only if your schedule has enough room.',
                ),
                onChanged: onAllowAdditionalCitiesChanged,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
