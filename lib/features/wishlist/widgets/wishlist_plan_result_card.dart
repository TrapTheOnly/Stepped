import 'package:flutter/material.dart';

import '../gemini_trip_models.dart';
import 'wishlist_city_plan_card.dart';
import 'wishlist_editor_shell.dart';

class WishlistPlanResultCard extends StatelessWidget {
  const WishlistPlanResultCard({super.key, required this.plan});

  final GeminiTripPlan plan;

  @override
  Widget build(BuildContext context) {
    final detailByCity = <String, GeminiCityDetail>{
      for (final detail in plan.cityDetails) _cityKey(detail.city): detail,
    };

    return WishlistEditorSectionCard(
      title: 'AI recommendation',
      subtitle:
          'Preview the generated summary, season windows, and city cards before heading back to plan review.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(plan.summary),
          if (plan.stayDuration != null) ...<Widget>[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: Theme.of(context).colorScheme.surfaceContainerHigh,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  CircleAvatar(
                    radius: 14,
                    child: Text('${plan.stayDuration!.days}d'),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          plan.stayDuration!.source == 'user_selected'
                              ? 'Duration matched to your preference'
                              : 'AI-recommended trip duration',
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          plan.stayDuration!.reason,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (plan.timeWindows.isNotEmpty) ...<Widget>[
            const SizedBox(height: 12),
            Text(
              'Best Time Windows',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 6),
            ...plan.timeWindows.map(
              (window) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color:
                        Theme.of(context).colorScheme.surfaceContainerHighest,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        window.label,
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                      const SizedBox(height: 2),
                      Text(window.months),
                      const SizedBox(height: 4),
                      Text(
                        window.reason,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
          if (plan.cityPlan.isNotEmpty) ...<Widget>[
            const SizedBox(height: 4),
            Text(
              'City Cards',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 6),
            ...plan.cityPlan.map(
              (city) => WishlistCityPlanCard(
                city: city,
                detail: detailByCity[_cityKey(city.city)],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

String _cityKey(String value) => value.trim().toLowerCase();
