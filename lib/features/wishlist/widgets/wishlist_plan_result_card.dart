import 'package:flutter/material.dart';

import '../gemini_trip_models.dart';
import 'wishlist_city_plan_card.dart';
import 'wishlist_editor_shell.dart';

class WishlistPlanResultCard extends StatelessWidget {
  const WishlistPlanResultCard({super.key, required this.plan});

  final GeminiTripPlan plan;

  @override
  Widget build(BuildContext context) {
    if (plan.cityPlan.isEmpty) {
      return const SizedBox.shrink();
    }

    final detailByCity = <String, GeminiCityDetail>{
      for (final detail in plan.cityDetails) _cityKey(detail.city): detail,
    };

    return WishlistEditorSectionCard(
      title: 'City cards',
      subtitle: 'Review the generated route and daily city ideas.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          ...plan.cityPlan.map(
            (city) => WishlistCityPlanCard(
              city: city,
              detail: detailByCity[_cityKey(city.city)],
            ),
          ),
        ],
      ),
    );
  }
}

String _cityKey(String value) => value.trim().toLowerCase();
