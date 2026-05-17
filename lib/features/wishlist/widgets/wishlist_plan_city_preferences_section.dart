import 'package:flutter/material.dart';

import 'wishlist_editor_shell.dart';

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
    return WishlistEditorSectionCard(
      title: 'Route hints',
      subtitle:
          'If you already have cities in mind, add up to six. If not, AI can build the route from scratch.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
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
              ),
              onChanged: onCitiesChanged,
            ),
          if (!noCities) ...<Widget>[
            const SizedBox(height: 10),
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
            const SizedBox(height: 10),
            Text(
              cityValidationText!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                  ),
            ),
          ],
          if (hasPreferredCityInput) ...<Widget>[
            const SizedBox(height: 10),
            SwitchListTile(
              value: allowAdditionalCities,
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'Allow nearby additions if they fit',
              ),
              subtitle: const Text(
                'AI may add 1-2 nearby cities only when the schedule has room.',
              ),
              onChanged: onAllowAdditionalCitiesChanged,
            ),
          ],
        ],
      ),
    );
  }
}
